-- Headless test for the Oil git status column in plugins/oil.lua.
-- Run: nvim --headless -u NONE -l nvim/test/oil_git_column_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/oil_git_column_spec.lua$", "")
package.path = here .. "/lua/?.lua;" .. here .. "/lua/?/init.lua;" .. package.path

local failures = {}
local function check(name, cond, detail)
  if cond then
    io.write("ok   - " .. name .. "\n")
  else
    io.write("FAIL - " .. name .. " :: " .. tostring(detail) .. "\n")
    table.insert(failures, name)
  end
end

-- Stub Oil down to the three pieces the column touches: the registry it
-- registers into, the entry field indexes, and the call that says which
-- directory a buffer is showing.
local registered = {}
package.preload["oil.columns"] = function()
  return {
    register = function(name, column)
      registered[name] = column
    end,
  }
end
package.preload["oil.constants"] = function()
  return {
    FIELD_ID = 1,
    FIELD_NAME = 2,
    FIELD_TYPE = 3,
    FIELD_META = 4,
  }
end
local current_dir = nil
package.preload["oil"] = function()
  return {
    get_current_dir = function()
      return current_dir
    end,
    setup = function() end,
  }
end
-- The redraw the column asks for once a listing lands.
local rerenders, rerender_opts = 0, nil
package.preload["oil.view"] = function()
  return {
    render_buffer_async = function(_, opts)
      rerenders = rerenders + 1
      rerender_opts = opts
    end,
  }
end
vim.notify = function() end

-- A real repo: commit B changes a file and leaves the worktree clean, so only a
-- base diff can see it.
local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")
local function git(args)
  local out = vim.fn.systemlist(vim.list_extend({ "git", "-C", repo }, args))
  assert(vim.v.shell_error == 0, table.concat(out, "\n"))
  return out
end
for _, name in ipairs({ "committed_mod", "gone", "untouched", "worktree_mod" }) do
  vim.fn.writefile({ name }, repo .. "/" .. name)
end
git({ "init", "-q", "-b", "master" })
git({ "config", "user.email", "t@t" })
git({ "config", "user.name", "t" })
git({ "add", "-A" })
git({ "commit", "-q", "-m", "A" })
git({ "update-ref", "refs/remotes/origin/master", git({ "rev-parse", "HEAD" })[1] })
vim.fn.writefile({ "changed and committed" }, repo .. "/committed_mod")
git({ "commit", "-q", "-am", "B" })
vim.fn.writefile({ "changed" }, repo .. "/worktree_mod")
vim.fn.writefile({ "new" }, repo .. "/untracked")
vim.fn.delete(repo .. "/gone")
current_dir = git({ "rev-parse", "--show-toplevel" })[1]

local gitdiff = require("config.gitdiff")
local spec = require("plugins.oil")
spec.config(nil, spec.opts)

check("the column is registered", type(registered.git_status) == "table", type(registered.git_status))
check("it renders", type(registered.git_status.render) == "function", type(registered.git_status.render))
check(
  "it parses, which oil needs to apply an edit",
  type(registered.git_status.parse) == "function",
  type(registered.git_status.parse)
)
check(
  "the column is asked for in the config, ahead of the icon",
  spec.opts.columns[1] == "git_status" and spec.opts.columns[2] == "icon",
  vim.inspect(spec.opts.columns)
)

-- Oil hands the column an internal entry, a per-column config, and the bufnr.
local function render(name)
  return registered.git_status.render({ 1, name, "file" }, {}, 0)
end
local function mark(name)
  local out = render(name)
  return type(out) == "table" and out[1] or out
end
local function highlight(name)
  local out = render(name)
  return type(out) == "table" and out[2] or nil
end

-- The listing runs in the background: the first render of a directory has no
-- marks, and the column asks Oil to redraw from its cached entries (no second
-- directory listing) once it lands.
local function settle()
  local before = rerenders
  vim.wait(2000, function()
    return rerenders > before
  end)
  return rerenders - before
end

-- At the index base: worktree changes only.
do
  check("the first render is blank while git runs", mark("worktree_mod") == "", "[" .. tostring(mark("worktree_mod")) .. "]")
  check("the landing asks oil to redraw once", settle() == 1, rerenders)
  check("from oil's cached entries", rerender_opts and rerender_opts.refetch == false, vim.inspect(rerender_opts))
  check("a modified file is marked", mark("worktree_mod") == "M", mark("worktree_mod"))
  check("it carries a highlight", highlight("worktree_mod") == "TelescopeResultsDiffChange", highlight("worktree_mod"))
  check("an untracked file is marked", mark("untracked") == "?", mark("untracked"))
  check("untracked has its own highlight", highlight("untracked") == "TelescopeResultsDiffUntracked", highlight("untracked"))
  check("a deleted file is marked", mark("gone") == "D", mark("gone"))
  check("deleted has its own highlight", highlight("gone") == "TelescopeResultsDiffDelete", highlight("gone"))
  check("an unchanged file renders blank", mark("untouched") == "", "[" .. tostring(mark("untouched")) .. "]")
  check("a file committed since the base is not marked yet", mark("committed_mod") == "", mark("committed_mod"))
end

-- Against a ref the committed change shows up too, which is the whole point of
-- sharing the base with the pickers and the tree.
do
  gitdiff.set_base("origin/master")
  render("committed_mod")
  settle()
  check("a committed change is marked against a ref base", mark("committed_mod") == "M", mark("committed_mod"))
  check("an unchanged file is still blank", mark("untouched") == "", "[" .. tostring(mark("untouched")) .. "]")
end

-- One listing per directory and base, not one per row. Counted at the spawn:
-- the listing's first git command, not the untracked-files follow-up.
do
  local listings = 0
  local git_fields_async = gitdiff.git_fields_async
  gitdiff.git_fields_async = function(dir, args, ...)
    if args[1] ~= "ls-files" then
      listings = listings + 1
    end
    return git_fields_async(dir, args, ...)
  end

  for _ = 1, 6 do
    render("worktree_mod")
    render("untouched")
  end
  check("the cache holds across rows", listings == 0, listings)

  gitdiff.set_base(nil)
  render("worktree_mod")
  check("a base change recomputes once", listings == 1, listings)
  render("untouched")
  check("and only once", listings == 1, listings)
  settle()

  -- <C-l> is oil's refresh. A base change redraws the tree on its own but not
  -- oil, whose buffer may hold unsaved edits, so the refresh the user asks for
  -- has to be the moment the marks are recomputed.
  local refreshed = 0
  package.preload["oil.actions"] = function()
    return {
      refresh = {
        desc = "Refresh current directory list",
        callback = function()
          refreshed = refreshed + 1
        end,
      },
    }
  end
  local refresh = spec.opts.keymaps["<C-l>"]
  check("<C-l> is mapped", type(refresh) == "table" and type(refresh.callback) == "function", vim.inspect(refresh))
  if type(refresh) == "table" and type(refresh.callback) == "function" then
    refresh.callback()
  end
  check("<C-l> runs oil's refresh", refreshed == 1, refreshed)
  render("worktree_mod")
  check("<C-l> recomputes the marks", listings == 2, listings)
  render("untouched")
  check("and only once per refresh", listings == 2, listings)
  settle()

  -- A buffer holding unsaved edits is never redrawn from under them: Oil's
  -- rerender clears the modified flag, which is exactly the bulk rename the
  -- column must not destroy. The marks wait for the user's own <C-l>.
  vim.bo.modified = true
  gitdiff.invalidate()
  local version = gitdiff.version()
  local before = rerenders
  render("worktree_mod")
  vim.wait(2000, function()
    return gitdiff.version() ~= version
  end)
  check("the listing still lands for a modified buffer", gitdiff.version() ~= version, gitdiff.version())
  check("but the buffer is not redrawn", rerenders == before, rerenders - before)
  vim.bo.modified = false
  gitdiff.git_fields_async = git_fields_async
end

-- parse has to strip the column back off a line, since oil reads edits out of
-- the buffer text.
do
  local value, rest = registered.git_status.parse("M  file.lua")
  check("parse takes the mark", value == "M", value)
  check("parse hands back the rest of the line", rest == "file.lua", rest)
end

-- Outside a repo the column stays silent rather than erroring or warning.
do
  local plain = vim.fn.tempname()
  vim.fn.mkdir(plain, "p")
  current_dir = plain
  check("outside a repo it renders blank", mark("anything") == "", "[" .. tostring(mark("anything")) .. "]")
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
