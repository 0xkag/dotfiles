-- Headless test for the shared diff-base listings in config.gitdiff.
-- Run: nvim/test/run.sh gitdiff
--
-- git C-quotes any path with whitespace in porcelain output and octal-escapes
-- non-ASCII under the default core.quotePath, in both `status --porcelain` and
-- `diff --name-status`. The listings must come back as the real paths, since
-- every view keys its marks by them, so the module has to ask for NUL-separated
-- output and parse that.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/gitdiff_spec.lua$", "")
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

local notes = {}
vim.notify = function(msg, level)
  if type(msg) == "string" and msg:find("^git") then
    table.insert(notes, { level = level, msg = msg })
  end
end

local gitdiff = require("config.gitdiff")

-- A repo whose awkward names cover each quoting rule: a space, a non-ASCII
-- byte, and a rename onto a name with a space. Commit A is the fake
-- origin/master; commit B modifies the spaced file; the worktree then modifies
-- the non-ASCII file, stages the rename, and leaves an untracked spaced file.
local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")
local function git(args)
  local out = vim.fn.systemlist(vim.list_extend({ "git", "-C", repo }, args))
  assert(vim.v.shell_error == 0, table.concat(out, "\n"))
  return out
end
local spaced = "a b.txt"
local accented = "na\195\175ve.txt"
local renamed = "new name.txt"
for _, name in ipairs({ "plain", spaced, accented, "old_name.txt" }) do
  vim.fn.writefile({ name }, repo .. "/" .. name)
end
git({ "init", "-q", "-b", "master" })
git({ "config", "user.email", "t@t" })
git({ "config", "user.name", "t" })
git({ "config", "core.quotepath", "true" })
git({ "add", "-A" })
git({ "commit", "-q", "-m", "A" })
git({ "update-ref", "refs/remotes/origin/master", git({ "rev-parse", "HEAD" })[1] })
vim.fn.writefile({ "changed and committed" }, repo .. "/" .. spaced)
git({ "commit", "-q", "-am", "B" })
vim.fn.writefile({ "changed" }, repo .. "/" .. accented)
git({ "mv", "old_name.txt", renamed })
vim.fn.writefile({ "new" }, repo .. "/un tracked.txt")
local root = git({ "rev-parse", "--show-toplevel" })[1]

local function by_path(files)
  local map = {}
  for _, file in ipairs(files or {}) do
    map[file.path] = file.status
  end
  return map
end

local function no_quoting(files)
  for _, file in ipairs(files or {}) do
    if file.path:find('"', 1, true) or file.path:find("\\", 1, true) then
      return false, file.path
    end
  end
  return true
end

-- Index base: git status, with paths as written on disk.
do
  gitdiff.set_base(nil)
  local files = gitdiff.changed_files(root)
  local statuses = by_path(files)
  check("index: non-ASCII modified file is listed by its real name", statuses[accented] ~= nil, vim.inspect(statuses))
  check("index: non-ASCII file is modified", statuses[accented] and statuses[accented]:find("M") ~= nil, statuses[accented])
  check("index: rename is listed under the new spaced name", statuses[renamed] ~= nil, vim.inspect(statuses))
  check("index: rename status is R", statuses[renamed] and statuses[renamed]:sub(1, 1) == "R", statuses[renamed])
  check("index: rename does not list the old name", statuses["old_name.txt"] == nil, statuses["old_name.txt"])
  check("index: untracked spaced file is listed", statuses["un tracked.txt"] == "??", statuses["un tracked.txt"])
  check("index: committed change is not listed", statuses[spaced] == nil, statuses[spaced])
  check("index: no path carries quoting", no_quoting(files))
  check("index: listing is sorted", files[1].path <= files[#files].path)
end

-- Ref base: git diff --name-status plus the untracked files.
do
  gitdiff.set_base("origin/master")
  local files = gitdiff.changed_files(root)
  local statuses = by_path(files)
  check("ref: spaced committed file is listed by its real name", statuses[spaced] == "M", vim.inspect(statuses))
  check("ref: non-ASCII worktree file is listed", statuses[accented] == "M", statuses[accented])
  check("ref: rename is listed under the new spaced name", statuses[renamed] ~= nil, vim.inspect(statuses))
  check("ref: rename status collapses to R", gitdiff.status_mark(statuses[renamed]) == "R", statuses[renamed])
  check("ref: untracked spaced file is listed", statuses["un tracked.txt"] == "??", statuses["un tracked.txt"])
  check("ref: no path carries quoting", no_quoting(files))

  local committed = by_path(gitdiff.committed_files(root))
  check("committed: spaced file is listed by its real name", committed[spaced] == "M", vim.inspect(committed))
  check("committed: worktree-only change is not listed", committed[accented] == nil, committed[accented])
  check("committed: no path carries quoting", no_quoting(gitdiff.committed_files(root)))

  local marks = gitdiff.status_by_path(root)
  check("marks: keyed by the real absolute path", marks[root .. "/" .. spaced] == "M", vim.inspect(marks))
  check("marks: non-ASCII key resolves", marks[root .. "/" .. accented] == "M", marks[root .. "/" .. accented])
  check("marks: untracked spaced key resolves", marks[root .. "/un tracked.txt"] == "?", marks[root .. "/un tracked.txt"])

  local args = gitdiff.file_diff_args({ path = renamed, status = statuses[renamed] })
  local out = vim.fn.systemlist(vim.list_extend({ "git", "-C", root }, args))
  check("preview: diff of the spaced rename runs", vim.v.shell_error == 0, table.concat(out, "\n"))
end

-- A failing git call still reports and returns nil rather than a partial list.
do
  gitdiff.set_base("no-such-ref")
  local files = gitdiff.changed_files(root)
  check("bad base returns nil", files == nil, vim.inspect(files))
  check("bad base notifies", #notes > 0 and notes[#notes].level == vim.log.levels.ERROR, vim.inspect(notes))
  gitdiff.set_base(nil)
end

vim.fn.delete(repo, "rf")

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
