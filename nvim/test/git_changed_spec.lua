-- Headless test for the project-wide change lists (<leader>gc / <leader>gC) in
-- plugins/git.lua.
-- Run: nvim --headless -u NONE -l nvim/test/git_changed_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/git_changed_spec.lua$", "")
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

-- Stub gitsigns: change_base is a no-op recorder, and setqflist stands in for
-- the real "all" scan by seeding a quickfix list with one in-repo hunk and one
-- from an unrelated repo, so the filtering in changed_hunks_list is exercised.
local setqflist_args = nil
local qf_seed = {}
package.preload["gitsigns"] = function()
  return {
    change_base = function() end,
    setqflist = function(target, opts, callback)
      setqflist_args = { target = target, open = opts.open }
      vim.fn.setqflist({}, " ", { items = qf_seed, title = "Hunks" })
      callback(nil)
    end,
  }
end

-- Stub telescope: capture the picker spec instead of opening a window.
local picked = nil
package.preload["telescope.config"] = function()
  return {
    values = {
      generic_sorter = function()
        return {}
      end,
    },
  }
end
package.preload["telescope.finders"] = function()
  return {
    new_table = function(opts)
      return opts
    end,
  }
end
package.preload["telescope.previewers"] = function()
  return {
    new_buffer_previewer = function(opts)
      return opts
    end,
  }
end
package.preload["telescope.pickers"] = function()
  return {
    new = function(_, opts)
      picked = opts
      return {
        find = function() end,
      }
    end,
  }
end

local notes = {}
vim.notify = function(msg, level)
  -- Ignore notifications from elsewhere in the editor (an unwritable log path,
  -- say); every message these code paths emit starts with "git".
  if type(msg) == "string" and msg:find("^git") then
    table.insert(notes, { level = level, msg = msg })
  end
end

-- Scratch repo. Commit A is the fake origin/master; commit B adds `added` on
-- top of it. The worktree then modifies `mod`, deletes `gone`, stages a rename
-- of `old` to `renamed`, and leaves `new` untracked -- one file per status the
-- lists have to render. Contents are distinct so git's rename detection cannot
-- pair `renamed` with the wrong deleted file.
local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")
local function sh(args)
  local out = vim.fn.systemlist(args)
  assert(vim.v.shell_error == 0, table.concat(args, " ") .. " failed: " .. table.concat(out, "\n"))
  return out
end
local function git(args)
  return sh(vim.list_extend({ "git", "-C", repo }, args))
end
local function write(name, text)
  vim.fn.writefile({ text }, repo .. "/" .. name)
end

git({ "init", "-q", "-b", "master" })
git({ "config", "user.email", "t@t" })
git({ "config", "user.name", "t" })
for _, name in ipairs({ "gone", "keep", "mod", "old" }) do
  write(name, name)
end
git({ "add", "-A" })
git({ "commit", "-q", "-m", "A" })
git({ "update-ref", "refs/remotes/origin/master", git({ "rev-parse", "HEAD" })[1] })
write("added", "added")
git({ "add", "added" })
git({ "commit", "-q", "-m", "B" })

write("mod", "mod changed")
vim.fn.delete(repo .. "/gone")
git({ "mv", "old", "renamed" })
write("new", "new")

-- Physical path: git reports --show-toplevel resolved, and the qflist filter
-- compares against it.
vim.cmd.cd(repo)
local root = git({ "rev-parse", "--show-toplevel" })[1]

-- A fresh repo holding one committed file, for the three ways a project-wide
-- hunk list can come back empty.
local function new_repo()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local function g(args)
    return sh(vim.list_extend({ "git", "-C", dir }, args))
  end
  vim.fn.writefile({ "base" }, dir .. "/committed")
  g({ "init", "-q", "-b", "master" })
  g({ "config", "user.email", "t@t" })
  g({ "config", "user.name", "t" })
  g({ "add", "-A" })
  g({ "commit", "-q", "-m", "A" })
  return dir
end

local function load_maps()
  -- The diff base lives in config.gitdiff now, so resetting the spec's view of
  -- the base means dropping both modules.
  package.loaded["config.gitdiff"] = nil
  package.loaded["plugins.git"] = nil
  local spec = require("plugins.git")
  local maps = {}
  for _, k in ipairs(spec.keys) do
    maps[k[1]] = k[2]
  end
  return maps
end

-- The picker's entries, in the order the finder lists them.
local function entries()
  local out = {}
  for _, file in ipairs(picked.finder.results) do
    table.insert(out, picked.finder.entry_maker(file))
  end
  return out
end

local function paths_of(list)
  local out = {}
  for _, entry in ipairs(list) do
    table.insert(out, entry.value)
  end
  return table.concat(out, " ")
end

local function status_of(list, path)
  for _, entry in ipairs(list) do
    if entry.value == path then
      return entry.status
    end
  end
  return nil
end

-- Rendering the previewer's diff for one entry, the way telescope would. The
-- diff runs in the background so moving through the list never waits on git:
-- the buffer is empty right after define_preview and filled once it lands.
-- Returns the landed text, what was there at once, and the landed filetype.
local function preview_lines(entry)
  local buf = vim.api.nvim_create_buf(false, true)
  picked.previewer.define_preview({ state = { bufnr = buf } }, entry)
  local at_once = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  vim.wait(2000, function()
    return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= ""
  end)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local filetype = vim.bo[buf].filetype
  vim.api.nvim_buf_delete(buf, { force = true })
  return table.concat(lines, "\n"), at_once, filetype
end

-- At the index base the list is git status: staged, unstaged, and untracked.
do
  local maps = load_maps()
  maps["<leader>gc"]()
  local list = entries()

  check("index base lists every changed file, sorted", paths_of(list) == "gone mod new renamed", paths_of(list))
  check("index base picker title", picked.prompt_title == "Changed vs index", picked.prompt_title)
  check("index base keeps the raw XY status", status_of(list, "mod") == " M", status_of(list, "mod"))
  check("index base reports the deletion", status_of(list, "gone") == " D", status_of(list, "gone"))
  check("index base reports the rename's new path", status_of(list, "renamed") == "R ", status_of(list, "renamed"))
  check("index base reports untracked", status_of(list, "new") == "??", status_of(list, "new"))

  local entry = list[2]
  local diff, at_once, filetype = preview_lines(entry)
  check("entry resolves to an absolute path", entry.path == root .. "/mod", entry.path)
  check("the preview does not block on git", at_once == "", at_once)
  check("index base preview diffs the worktree", diff:find("+mod changed", 1, true) ~= nil, diff)
  check("the landed preview is a diff buffer", filetype == "diff", filetype)
end

-- Against a ref the list is git diff --name-status plus untracked files, so it
-- also picks up files changed by commits this branch already made.
do
  local maps = load_maps()
  vim.ui.input = function(_, cb)
    cb("origin/master")
  end
  maps["<leader>gM"]()
  maps["<leader>gc"]()
  local list = entries()

  check("ref base includes committed changes", paths_of(list) == "added gone mod new renamed", paths_of(list))
  check("ref base picker title", picked.prompt_title == "Changed vs origin/master", picked.prompt_title)
  check("ref base detects the rename", (status_of(list, "renamed") or ""):sub(1, 1) == "R", status_of(list, "renamed"))
  check("ref base still lists untracked", status_of(list, "new") == "??", status_of(list, "new"))

  local added = preview_lines(list[1])
  check("ref base preview diffs against the ref", added:find("+added", 1, true) ~= nil, added)

  local untracked = preview_lines(list[4])
  check("untracked preview falls back to --no-index", untracked:find("+new", 1, true) ~= nil, untracked)
end

-- gC delegates the scan to gitsigns, then narrows the list to this repo and
-- retitles it with the active base.
do
  local maps = load_maps()
  vim.ui.input = function(_, cb)
    cb("origin/master")
  end
  maps["<leader>gM"]()

  qf_seed = {
    { filename = root .. "/mod", lnum = 1, text = "Changed (-1 +1): mod changed" },
    { filename = "/tmp/other-repo/elsewhere", lnum = 1, text = "Changed (-1 +1): nope" },
  }
  maps["<leader>gC"]()
  vim.wait(2000, function()
    return vim.fn.getqflist({ title = 1 }).title ~= "Hunks"
  end)

  local items = vim.fn.getqflist()
  check("gC asks gitsigns for every repo", setqflist_args and setqflist_args.target == "all", vim.inspect(setqflist_args))
  check("gC suppresses gitsigns' own window", setqflist_args and setqflist_args.open == false, vim.inspect(setqflist_args))
  check("gC drops hunks from other repos", #items == 1, #items)
  check(
    "gC titles the list with the base",
    vim.fn.getqflist({ title = 1 }).title == "Hunks vs origin/master",
    vim.fn.getqflist({ title = 1 }).title
  )
  vim.cmd.cclose()
end

-- An empty hunk list has three unrelated causes and gitsigns' output cannot
-- tell them apart, so gC asks git before reporting. Seeding the scan with an
-- out-of-repo hunk only is what makes the filtered list empty in each case.
do
  local function reason_for(dir)
    local maps = load_maps()
    vim.cmd.cd(dir)
    qf_seed = { { filename = "/tmp/other-repo/elsewhere", lnum = 1, text = "nope" } }
    notes = {}
    maps["<leader>gC"]()
    vim.wait(2000, function()
      return #notes > 0
    end)
    return notes[1] or {}
  end

  local clean = reason_for(new_repo())
  check("clean repo reports no changes", (clean.msg or ""):find("no changes vs index", 1, true) ~= nil, clean.msg)
  check("clean repo is not a warning", clean.level == nil, clean.level)

  local tracked = new_repo()
  vim.fn.writefile({ "edited" }, tracked .. "/committed")
  local unscanned = reason_for(tracked)
  check(
    "tracked changes but no hunks blames the scan scope",
    (unscanned.msg or ""):find("hunk scan found none", 1, true) ~= nil,
    unscanned.msg
  )
  check("unscanned repo warns", unscanned.level == vim.log.levels.WARN, unscanned.level)

  local others = new_repo()
  vim.fn.writefile({ "fresh" }, others .. "/untracked")
  local skipped = reason_for(others)
  check(
    "untracked-only names the attach_to_untracked gap",
    (skipped.msg or ""):find("attach_to_untracked", 1, true) ~= nil,
    skipped.msg
  )
  check("untracked-only is not a warning", skipped.level == nil, skipped.level)
end

if #failures > 0 then
  vim.cmd("cquit 1")
end
vim.cmd("quit")
