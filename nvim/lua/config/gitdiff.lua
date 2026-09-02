local M = {}

local util = require("config.util")
local uv = vim.uv or vim.loop

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

-- git_in in the background: `callback(lines, code)` runs on the main loop once
-- git exits, with the output split into lines the way systemlist() splits it.
function M.git_in_async(dir, args, callback)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true }, function(result)
    local lines = vim.split(result.stdout or "", "\n", { plain = true })
    if lines[#lines] == "" then
      table.remove(lines)
    end
    vim.schedule(function()
      callback(lines, result.code)
    end)
  end)
end

-- Run git in `dir` with -z output: one NUL-terminated field per record, so a
-- path comes back exactly as written on disk. Without it git C-quotes any path
-- containing whitespace in porcelain output and octal-escapes non-ASCII under
-- the default core.quotePath, in diff --name-status too, and a listing keyed by
-- those strings never matches the file it describes. Note that systemlist()
-- turns NUL into a newline, so this reads the raw bytes instead.
local function split_fields(stdout)
  return vim.split(stdout or "", "\0", { plain = true, trimempty = true })
end

function M.git_fields(dir, args)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { text = false }):wait()
  return split_fields(result.stdout), result.code, result.stderr or ""
end

-- The same in the background: `callback(fields, code, stderr)` runs on the main
-- loop once git exits.
function M.git_fields_async(dir, args, callback)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = false }, function(result)
    local fields = split_fields(result.stdout)
    vim.schedule(function()
      callback(fields, result.code, result.stderr or "")
    end)
  end)
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

-- The git command that lists the changes at the active base, with its parser.
-- Untracked files are invisible to git diff, so against a ref they come from a
-- second command; git status already includes them.
local untracked_args = { "ls-files", "-z", "--others", "--exclude-standard" }

local function changed_command()
  if base_ref then
    return { "diff", "--name-status", "-z", submodules, base_ref }, parse_name_status
  end
  return { "status", "--porcelain", "-z", submodules }, parse_porcelain
end

local function report_failure(args, err, quiet)
  if not quiet then
    vim.notify("git " .. args[1] .. " " .. args[2] .. " failed: " .. vim.trim(err), vim.log.levels.ERROR)
  end
end

-- The sorted listing from the parsed changes plus the untracked paths.
local function assemble(files, others)
  for _, path in ipairs(others or {}) do
    table.insert(files, { path = path, status = "??" })
  end
  table.sort(files, function(a, b)
    return a.path < b.path
  end)
  return files
end

-- Every file changed against the active diff base, as { path, status } with
-- repo-relative paths, sorted by path. At the index base that is git status
-- (staged, unstaged, and untracked); against a ref it is git diff
-- --name-status plus the untracked files, which a diff cannot see but are
-- still part of what this branch changed. Renames report the new path.
local function list_changed(root, quiet)
  local args, parse = changed_command()
  local fields, code, err = M.git_fields(root, args)
  if code ~= 0 then
    report_failure(args, err, quiet)
    return nil
  end

  local others = nil
  if base_ref then
    local other_fields, others_code = M.git_fields(root, untracked_args)
    others = others_code == 0 and other_fields or nil
  end
  return assemble(parse(fields), others)
end

-- list_changed in the background; `callback(files)` gets nil on failure.
local function list_changed_async(root, quiet, callback)
  local args, parse = changed_command()
  local with_untracked = base_ref ~= nil
  M.git_fields_async(root, args, function(fields, code, err)
    if code ~= 0 then
      report_failure(args, err, quiet)
      callback(nil)
      return
    end

    local files = parse(fields)
    if not with_untracked then
      callback(assemble(files))
      return
    end
    M.git_fields_async(root, untracked_args, function(other_fields, others_code)
      callback(assemble(files, others_code == 0 and other_fields or nil))
    end)
  end)
end

-- The cached changed_files listing for `root`, listed on the first ask since
-- the last invalidation. Shared between callers, so treat it as read-only.
-- `quiet` keeps a failure off the screen, for callers redrawing a view.
function M.changed_files(root, quiet)
  local listing = listing_for(root)
  if listing.changed == nil then
    listing.changed = list_changed(root, quiet) or false
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

-- `path`, physical and under the repo toplevel, spelled the way the caller
-- spells `dir`, whose physical form is `physical`. git reports the physical
-- toplevel, while a buffer name, an Oil directory or a tree root can reach the
-- same files through a symlink (~/.config/nvim -> ~/.dotfiles/nvim), above the
-- repo or inside it, and a lookup by the caller's spelling would then find
-- nothing. Paths outside `dir` keep the physical spelling.
local function respell(path, dir, physical)
  if dir == physical then
    return path
  end
  if path == physical then
    return dir
  end
  if vim.startswith(path, physical .. "/") then
    return dir .. path:sub(#physical + 1)
  end
  return path
end

-- Absolute path -> mark for `files`, keyed the way the caller spells `dir`.
local function marks_for(root, files, dir)
  if #dir > 1 then
    dir = (dir:gsub("/+$", ""))
  end
  local physical = uv.fs_realpath(dir) or dir

  local marks = {}
  for _, file in ipairs(files or {}) do
    marks[respell(vim.fs.joinpath(root, file.path), dir, physical)] = M.status_mark(file.status)
  end
  return marks
end

-- Absolute path -> status mark for what this branch committed since the base,
-- keyed like status_by_path, for the tree's base marks. Blocking, since it
-- never touches the worktree and is cheap. At the index base there is nothing
-- to list, and git is not asked at all.
function M.committed_by_path(dir, quiet)
  if not base_ref then
    return {}
  end

  dir = dir or util.project_root(0)
  local root = M.repo_toplevel(dir, quiet)
  if not root then
    return {}
  end
  return marks_for(root, M.committed_files(root), dir)
end

-- Absolute path -> status mark for everything changed against the active base,
-- for decorating file views that list far more than the changed files. The
-- keys follow the caller's spelling of `dir` (see respell). `opts.quiet` is for
-- callers that may be pointed outside a repo or redraw on a bad base, such as
-- a directory editor, and keeps both failures silent.
--
-- With `opts.on_update` the listing runs in the background: the call answers
-- from the cache when it can and otherwise returns what is known now, nothing,
-- and the callback is told once the listing has landed and should ask again.
-- However many views ask meanwhile, one listing runs and every callback is
-- told. A landing bumps the version, so a view that cached the empty answer
-- knows to ask again too. Without a callback the call blocks, for the callers
-- that need the answer now, such as a jump.
function M.status_by_path(dir, opts)
  opts = opts or {}
  dir = dir or util.project_root(0)
  local root = M.repo_toplevel(dir, opts.quiet)
  if not root then
    return {}
  end

  local listing = listing_for(root)
  if listing.changed ~= nil then
    return marks_for(root, listing.changed or nil, dir)
  end
  if not opts.on_update then
    return marks_for(root, M.changed_files(root, opts.quiet), dir)
  end

  -- Callbacks collect on the listing record while it is in flight. A stale
  -- landing, one issued before the base changed or the cache was dropped, is
  -- not stored, but its callbacks still run so the views ask again and get the
  -- fresh one.
  if listing.pending then
    table.insert(listing.pending, opts.on_update)
    return {}
  end
  listing.pending = { opts.on_update }
  list_changed_async(root, opts.quiet, function(files)
    local callbacks = listing.pending
    listing.pending = nil
    if listings[root] == listing then
      listing.changed = files or false
      version = version + 1
    end
    for _, callback in ipairs(callbacks) do
      callback()
    end
  end)
  return {}
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
