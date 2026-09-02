-- Headless test for the neo-tree diff-base marks in plugins/neotree.lua: the
-- files a branch committed since the base, which a worktree status cannot see.
-- Run: nvim --headless -u NONE -l nvim/test/neotree_base_marks_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/neotree_base_marks_spec.lua$", "")
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

-- Stand in for neo-tree's own git_status component: it reports a worktree
-- status for the paths named in `worktree` and an empty table for everything
-- else, which is the opening the base marks fill.
local worktree = {}
local sources = { "buffers", "filesystem", "git_status" }
for _, source in ipairs(sources) do
  package.preload["neo-tree.sources." .. source .. ".components"] = function()
    return {
      git_status = function(_, node)
        if node and worktree[node.path] then
          return { highlight = "NeoTreeGitModified", text = worktree[node.path] .. " " }
        end
        return {}
      end,
      icon = function(config)
        return { config = config }
      end,
      indent = function(config)
        return { config = config }
      end,
      symlink_target = function(config)
        return { config = config }
      end,
    }
  end
end
local refreshes = 0
package.preload["neo-tree.sources.manager"] = function()
  return {
    get_state = function()
      return { path = "/nowhere" }
    end,
    refresh = function()
      refreshes = refreshes + 1
    end,
  }
end
-- The jump needs three more pieces of neo-tree: a path helper, a sorter, and
-- the two ways it moves the cursor.
local focused = nil
package.preload["neo-tree.utils"] = function()
  return {
    is_subpath = function(root, path)
      return path == root or path:sub(1, #root + 1) == root .. "/"
    end,
    sort_by_tree_display = function(paths)
      local sorted = vim.deepcopy(paths)
      table.sort(sorted)
      return sorted
    end,
  }
end
package.preload["neo-tree.ui.renderer"] = function()
  return {
    focus_node = function(_, target)
      focused = target
    end,
  }
end
package.preload["neo-tree.sources.filesystem"] = function()
  return {
    navigate = function(_, _, target)
      focused = target
    end,
  }
end

local subscriptions = {}
package.preload["neo-tree.events"] = function()
  return {
    GIT_STATUS_CHANGED = "git_status_changed",
    subscribe = function(spec)
      subscriptions[spec.event] = spec.handler
    end,
  }
end
package.preload["neo-tree"] = function()
  return {
    setup = function() end,
  }
end
vim.notify = function() end

-- A real repo: commit A is the base, commit B changes two files and leaves the
-- worktree clean, so only a base diff can see them.
local repo = vim.fn.tempname()
vim.fn.mkdir(repo .. "/sub", "p")
local function git(args)
  local out = vim.fn.systemlist(vim.list_extend({ "git", "-C", repo }, args))
  assert(vim.v.shell_error == 0, table.concat(out, "\n"))
  return out
end
for _, name in ipairs({ "committed_mod", "untouched", "worktree_mod" }) do
  vim.fn.writefile({ name }, repo .. "/" .. name)
end
vim.fn.writefile({ "deep" }, repo .. "/sub/committed_deep")
git({ "init", "-q", "-b", "master" })
git({ "config", "user.email", "t@t" })
git({ "config", "user.name", "t" })
git({ "add", "-A" })
git({ "commit", "-q", "-m", "A" })
git({ "update-ref", "refs/remotes/origin/master", git({ "rev-parse", "HEAD" })[1] })
vim.fn.writefile({ "changed and committed" }, repo .. "/committed_mod")
vim.fn.writefile({ "changed deep" }, repo .. "/sub/committed_deep")
git({ "commit", "-q", "-am", "B" })
local root = git({ "rev-parse", "--show-toplevel" })[1]

local gitdiff = require("config.gitdiff")
local spec = require("plugins.neotree")
spec.config(nil, spec.opts)

-- Oil is the default file explorer (`:e somedir/` opens it), so neo-tree must
-- not also claim netrw's directory buffers.
check(
  "neo-tree leaves directory buffers to oil",
  spec.opts.filesystem.hijack_netrw_behavior == "disabled",
  spec.opts.filesystem.hijack_netrw_behavior
)

-- Count the git calls the marks cost, to prove the cache holds.
local listings = 0
local committed_files = gitdiff.committed_files
gitdiff.committed_files = function(...)
  listings = listings + 1
  return committed_files(...)
end

local component = require("neo-tree.sources.filesystem.components").git_status
local state = { path = root }
local function render(name)
  return component({ symbols = { modified = "M", added = "A", deleted = "D", renamed = "R" } }, {
    path = root .. "/" .. name,
  }, state)
end

-- At the index base the base is the index, so there is nothing a worktree
-- status has not already covered.
do
  local out = render("committed_mod")
  check("no base marks at the index base", vim.trim(out.text or "") == "", vim.inspect(out))
end

-- Against a ref, a file committed on this branch and clean now gets marked, in
-- its own highlight so it reads differently from an uncommitted change.
gitdiff.set_base("origin/master")
do
  local marked = render("committed_mod")
  check("a committed change is marked", vim.trim(marked.text or "") == "M", vim.inspect(marked))
  check("it uses the base highlight", marked.highlight == "NeoTreeGitBase", marked.highlight)

  local deep = render("sub/committed_deep")
  check("a nested committed change is marked", vim.trim(deep.text or "") == "M", vim.inspect(deep))

  local bubbled = render("sub")
  check("the parent directory bubbles up", vim.trim(bubbled.text or "") == "M", vim.inspect(bubbled))
  check("the bubbled mark uses the base highlight", bubbled.highlight == "NeoTreeGitBase", bubbled.highlight)

  local clean = render("untouched")
  check("an unchanged file stays unmarked", vim.trim(clean.text or "") == "", vim.inspect(clean))
end

-- Worktree status wins: not-yet-committed is the more urgent fact, and the
-- component must not paint over it.
do
  worktree[root .. "/committed_mod"] = "W"
  local out = render("committed_mod")
  check("worktree status wins over the base mark", vim.trim(out.text or "") == "W", vim.inspect(out))
  check("and keeps its own highlight", out.highlight == "NeoTreeGitModified", out.highlight)
  worktree[root .. "/committed_mod"] = nil
end

-- One listing per refresh, not per row.
do
  listings = 0
  for _ = 1, 5 do
    render("committed_mod")
    render("untouched")
  end
  check("the cache holds across rows", listings == 0, listings)

  subscriptions["git_status_changed"]()
  render("committed_mod")
  check("a tree refresh recomputes once", listings == 1, listings)

  render("untouched")
  check("and only once", listings == 1, listings)
end

-- Changing the base invalidates the cache and asks the tree to redraw, but only
-- when a tree is on screen; pretend one is by claiming the filetype.
do
  listings, refreshes = 0, 0
  gitdiff.set_base("HEAD~2")
  check("a base change with no tree open refreshes nothing", refreshes == 0, refreshes)

  vim.bo.filetype = "neo-tree"
  gitdiff.set_base("HEAD~1")
  vim.bo.filetype = ""
  check("a base change refreshes an open tree", refreshes == 1, refreshes)
  render("committed_mod")
  check("a base change recomputes the marks", listings == 1, listings)
end

-- Back at the index base the marks go away again.
do
  gitdiff.set_base(nil)
  local out = render("committed_mod")
  check("resetting to the index clears the marks", vim.trim(out.text or "") == "", vim.inspect(out))
end

-- A tree rooted at a symlinked spelling of the repo (~/.config/nvim ->
-- ~/.dotfiles/nvim) has node paths under that spelling while git reports the
-- physical toplevel, so the marks have to be keyed the way the tree spells
-- them. And at the index base there is nothing to list, so nothing is asked of
-- git at all.
do
  local link = vim.fn.tempname()
  vim.uv.fs_symlink(root, link)
  local linked = { path = link }
  local config = { symbols = { modified = "M", added = "A", deleted = "D", renamed = "R" } }

  gitdiff.set_base("origin/master")
  subscriptions["git_status_changed"]()
  local marked = component(config, { path = link .. "/committed_mod" }, linked)
  check("a committed change is marked under the tree's own spelling", vim.trim(marked.text or "") == "M", vim.inspect(marked))
  local bubbled = component(config, { path = link .. "/sub" }, linked)
  check("and bubbles up under it", vim.trim(bubbled.text or "") == "M", vim.inspect(bubbled))
  local clean = component(config, { path = link .. "/untouched" }, linked)
  check("an unchanged file stays unmarked there", vim.trim(clean.text or "") == "", vim.inspect(clean))

  gitdiff.set_base(nil)
  local rev_parses = 0
  local git_in = gitdiff.git_in
  gitdiff.git_in = function(dir, args)
    if args[1] == "rev-parse" then
      rev_parses = rev_parses + 1
    end
    return git_in(dir, args)
  end
  subscriptions["git_status_changed"]()
  component(config, { path = link .. "/committed_mod" }, linked)
  check("the index base asks git nothing", rev_parses == 0, rev_parses)
  gitdiff.git_in = git_in
  vim.fn.delete(link)
end

-- ]g and [g have to walk the same set the rows are marked with. Neo-tree's own
-- versions read its worktree status table, which never sees the base marks and
-- skips untracked files outright.
do
  local next_changed = spec.opts.window.mappings["]g"][1]
  local prev_changed = spec.opts.window.mappings["[g"][1]

  -- Up to here the worktree has been clean, since the point was that only a
  -- base diff could see commit B. The jump has to cover both kinds at once, so
  -- add a real worktree change and a real untracked file.
  vim.fn.writefile({ "changed in worktree" }, repo .. "/worktree_mod")
  vim.fn.writefile({ "brand new" }, repo .. "/untracked")

  -- A state whose cursor follows whatever the last jump focused, the way the
  -- real one does.
  local cursor = root
  local jump_state = {
    path = root,
    tree = {
      get_node = function()
        return {
          get_id = function()
            return cursor
          end,
        }
      end,
    },
  }

  local function walk(jump, count)
    local seq = {}
    for _ = 1, count do
      focused = nil
      jump(jump_state)
      cursor = focused or cursor
      table.insert(seq, focused and vim.fn.fnamemodify(focused, ":t") or "<none>")
    end
    return table.concat(seq, " ")
  end

  -- committed_mod changed only in commit B; worktree_mod only in the worktree;
  -- untracked is untracked. gone was deleted, so it is not a file on disk and
  -- cannot be jumped to.
  gitdiff.set_base(nil)
  cursor = root
  local at_index = walk(next_changed, 4)
  check("at the index base it visits the worktree change", at_index:find("worktree_mod", 1, true), at_index)
  check("and the untracked file, which neo-tree's own jump skips", at_index:find("untracked", 1, true), at_index)
  check(
    "but not the committed one, which the index base cannot see",
    at_index:find("committed_mod", 1, true) == nil,
    at_index
  )

  gitdiff.set_base("origin/master")
  cursor = root
  local at_base = walk(next_changed, 4)
  check(
    "against a ref it also visits the committed change",
    at_base:find("committed_mod", 1, true) ~= nil,
    at_base
  )
  check("and still visits the worktree change", at_base:find("worktree_mod", 1, true) ~= nil, at_base)
  check("and the untracked one", at_base:find("untracked", 1, true) ~= nil, at_base)

  cursor = root
  local backwards = walk(prev_changed, 3)
  check("[g walks the other way", backwards ~= at_base:sub(1, #backwards), backwards)

  -- A clean repo has nothing to jump to, so the cursor must not move.
  local clean = vim.fn.tempname()
  vim.fn.mkdir(clean, "p")
  vim.fn.writefile({ "only file" }, clean .. "/file")
  for _, args in ipairs({
    { "init", "-q", "-b", "master" },
    { "config", "user.email", "t@t" },
    { "config", "user.name", "t" },
    { "add", "-A" },
    { "commit", "-q", "-m", "A" },
  }) do
    vim.fn.systemlist(vim.list_extend({ "git", "-C", clean }, args))
  end

  gitdiff.set_base(nil)
  cursor = clean
  focused = nil
  next_changed({ path = clean, tree = jump_state.tree })
  check("a clean repo moves nothing", focused == nil, tostring(focused))
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
