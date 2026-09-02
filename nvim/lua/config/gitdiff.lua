local M = {}

local util = require("config.util")

-- The diff base the project-wide views share. <leader>gm and <leader>gM set it
-- through gitsigns; the change lists and the file pickers read it from here so
-- they cannot disagree about what "changed" means. nil is gitsigns' own default
-- of the index, i.e. uncommitted changes only.
local base_ref = nil

-- Run git in `dir` so the right repo is used regardless of nvim's cwd.
function M.git_in(dir, args)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  local out = vim.fn.systemlist(cmd)
  return out, vim.v.shell_error
end

-- Run git in `dir` with -z output: one NUL-terminated field per record, so a
-- path comes back exactly as written on disk. Without it git C-quotes any path
-- containing whitespace in porcelain output and octal-escapes non-ASCII under
-- the default core.quotePath, in diff --name-status too, and a listing keyed by
-- those strings never matches the file it describes. Note that systemlist()
-- turns NUL into a newline, so this reads the raw bytes instead.
function M.git_fields(dir, args)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { text = false }):wait()
  local fields = vim.split(result.stdout or "", "\0", { plain = true, trimempty = true })
  return fields, result.code, result.stderr or ""
end

-- Parse `diff --name-status -z` fields into { path, status } records. Each
-- record is a status field then a path field, except renames and copies, which
-- carry the old path and then the new one; the new path is what the file is
-- called now, so that is the one reported.
local function parse_name_status(fields)
  local files = {}
  local i = 1
  while i <= #fields do
    local status = fields[i]
    local kind = status:sub(1, 1)
    local path
    if kind == "R" or kind == "C" then
      path = fields[i + 2]
      i = i + 3
    else
      path = fields[i + 1]
      i = i + 2
    end
    if path and path ~= "" then
      table.insert(files, { path = path, status = status })
    end
  end
  return files
end

-- Parse `status --porcelain -z` fields into { path, status } records. Each
-- record is "XY path", and a rename or copy in either column is followed by one
-- more field holding the original path, which is skipped.
local function parse_porcelain(fields)
  local files = {}
  local i = 1
  while i <= #fields do
    local entry = fields[i]
    local status = entry:sub(1, 2)
    local path = entry:sub(4)
    if status:find("[RC]") then
      i = i + 2
    else
      i = i + 1
    end
    if path ~= "" then
      table.insert(files, { path = path, status = status })
    end
  end
  return files
end

function M.base()
  return base_ref
end

-- The listings, one per repo toplevel, shared by every view: Oil asks per
-- directory change, the pickers per open, the tree per refresh and ]g per
-- press, and until something changes they would all get the same answer. A
-- listing that failed is kept as false, so a bad base costs one spawn and one
-- error rather than one of each per redraw. `toplevels` memoizes rev-parse per
-- directory alongside.
local listings = {}
local toplevels = {}

-- Bumped whenever the listings may have changed: a base change, or a sign that
-- the worktree did (the autocmds at the end). A view that caches marks keys
-- them by this and notices without registering a callback.
local version = 0

local function forget()
  version = version + 1
  listings = {}
  toplevels = {}
end

function M.version()
  return version
end

-- Drop every cached listing. The autocmds below call this on the events that
-- bracket a git command the editor cannot see; Oil's <C-l> calls it for the
-- refresh the user asks for.
function M.invalidate()
  forget()
end

function M.set_base(ref)
  base_ref = ref
  forget()
  -- Announced as a User event too, so an open view can redraw rather than
  -- waiting for its next refresh.
  vim.api.nvim_exec_autocmds("User", { pattern = "GitDiffBaseChanged" })
end

local function listing_for(root)
  local listing = listings[root]
  if not listing then
    listing = {}
    listings[root] = listing
  end
  return listing
end

-- Human-readable name for the active base, for list and picker titles.
function M.label()
  return base_ref or "index"
end

-- Toplevel of the git repo holding `dir`, defaulting to the current buffer's
-- project. git diff and git status report paths relative to this, and resolving
-- it from the project root rather than nvim's cwd keeps the project's repo in
-- play no matter where nvim was started.
-- `quiet` is for callers that probe speculatively, such as a file tree that may
-- be pointed anywhere and should not complain on every redraw.
function M.repo_toplevel(dir, quiet)
  dir = dir or util.project_root(0)
  local root = toplevels[dir]
  if root == nil then
    local out, code = M.git_in(dir, { "rev-parse", "--show-toplevel" })
    root = code == 0 and out[1] ~= nil and out[1] ~= "" and out[1] or false
    toplevels[dir] = root
  end

  if not root then
    if not quiet then
      vim.notify("git: not inside a git repository", vim.log.levels.WARN)
    end
    return nil
  end
  return root
end

-- Submodules are compared by recorded commit only. Calling one dirty means
-- walking its whole worktree, and in a repo with many that is where nearly all
-- of a listing's time goes: 137 ms against 9 ms for ~/.dotfiles and its 52.
-- A submodule whose commit moved is a change to this repo and is still listed.
local submodules = "--ignore-submodules=dirty"

-- Every file changed against the active diff base, as { path, status } with
-- repo-relative paths, sorted by path. At the index base that is git status
-- (staged, unstaged, and untracked); against a ref it is git diff
-- --name-status plus the untracked files, which a diff cannot see but are
-- still part of what this branch changed. Renames report the new path.
local function list_changed(root)
  local files

  if base_ref then
    local fields, code, err = M.git_fields(root, { "diff", "--name-status", "-z", submodules, base_ref })
    if code ~= 0 then
      vim.notify("git diff --name-status failed: " .. vim.trim(err), vim.log.levels.ERROR)
      return nil
    end
    files = parse_name_status(fields)

    -- Untracked files are invisible to git diff, so list them separately.
    local others, others_code = M.git_fields(root, { "ls-files", "-z", "--others", "--exclude-standard" })
    if others_code == 0 then
      for _, path in ipairs(others) do
        table.insert(files, { path = path, status = "??" })
      end
    end
  else
    local fields, code, err = M.git_fields(root, { "status", "--porcelain", "-z", submodules })
    if code ~= 0 then
      vim.notify("git status --porcelain failed: " .. vim.trim(err), vim.log.levels.ERROR)
      return nil
    end
    files = parse_porcelain(fields)
  end

  table.sort(files, function(a, b)
    return a.path < b.path
  end)
  return files
end

-- The cached changed_files listing for `root`, listed on the first ask since
-- the last invalidation. Shared between callers, so treat it as read-only.
function M.changed_files(root)
  local listing = listing_for(root)
  if listing.changed == nil then
    listing.changed = list_changed(root) or false
  end
  return listing.changed or nil
end

-- git diff arguments for one file against the active base. Untracked files have
-- nothing to diff against, so --no-index against /dev/null renders them as
-- all-added instead of as an empty diff.
function M.file_diff_args(file)
  if file.status == "??" then
    return { "diff", "--no-index", "--", "/dev/null", file.path }
  end
  local args = { "diff" }
  if base_ref then
    table.insert(args, base_ref)
  end
  vim.list_extend(args, { "--", file.path })
  return args
end

-- Files this branch changed in commits since the base, i.e. base..HEAD, as
-- { path, status } with repo-relative paths. Complements changed_files: that
-- one answers "what differs from the base", this one narrows it to what is
-- already committed, which is what a worktree status cannot see. At the index
-- base there is nothing to report, since the base is the index and git status
-- already covers everything it would list.
function M.committed_files(root)
  if not base_ref then
    return {}
  end

  local listing = listing_for(root)
  if not listing.committed then
    local fields, code = M.git_fields(root, { "diff", "--name-status", "-z", submodules, base_ref, "HEAD" })
    listing.committed = code == 0 and parse_name_status(fields) or {}
  end
  return listing.committed
end

-- One character standing in for a status, for a narrow picker column: the
-- change type from git diff (M/A/D/R/C), the first of the two porcelain status
-- columns, or ? for untracked. R100-style similarity scores collapse to R.
function M.status_mark(status)
  local trimmed = vim.trim(status or "")
  if trimmed == "" then
    return ""
  end
  if trimmed:sub(1, 1) == "?" then
    return "?"
  end
  return trimmed:sub(1, 1)
end

-- Status mark -> highlight group. Telescope defines these, linked to the Diff*
-- groups, and its own git_status picker paints with them, so reusing them keeps
-- one visual language across every view that shows a mark.
local status_highlights = {
  A = "TelescopeResultsDiffAdd",
  C = "TelescopeResultsDiffChange",
  D = "TelescopeResultsDiffDelete",
  M = "TelescopeResultsDiffChange",
  R = "TelescopeResultsDiffChange",
  U = "TelescopeResultsDiffAdd",
  ["?"] = "TelescopeResultsDiffUntracked",
}

function M.status_highlight(mark)
  return status_highlights[mark] or "TelescopeResultsDiffChange"
end

-- Absolute path -> status mark for everything changed against the active base,
-- for decorating file views that list far more than the changed files. `quiet`
-- is passed through for callers that may be pointed outside a repo, such as a
-- directory editor.
function M.status_by_path(dir, quiet)
  local root = M.repo_toplevel(dir, quiet)
  if not root then
    return {}
  end

  local marks = {}
  for _, file in ipairs(M.changed_files(root) or {}) do
    marks[vim.fs.joinpath(root, file.path)] = M.status_mark(file.status)
  end
  return marks
end

-- The worktree changes behind the editor's back through git commands it never
-- sees, so drop the listings on the events that bracket one: a write (the
-- file's own status changed), a :! command, leaving a terminal, regaining focus
-- after a shell in another window, and the events gitsigns and Oil raise after
-- mutating the repo or the directory.
local group = vim.api.nvim_create_augroup("user_gitdiff", { clear = true })
vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained", "ShellCmdPost", "TermLeave" }, {
  group = group,
  callback = function()
    M.invalidate()
  end,
  desc = "Drop the cached git listings when the worktree may have changed",
})
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = { "GitSignsChanged", "OilActionsPost" },
  callback = function()
    M.invalidate()
  end,
  desc = "Drop the cached git listings after a gitsigns or Oil mutation",
})

return M
