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

function M.base()
  return base_ref
end

function M.set_base(ref)
  base_ref = ref
end

-- Human-readable name for the active base, for list and picker titles.
function M.label()
  return base_ref or "index"
end

-- Toplevel of the git repo holding `dir`, defaulting to the current buffer's
-- project. git diff and git status report paths relative to this, and resolving
-- it from the project root rather than nvim's cwd keeps the project's repo in
-- play no matter where nvim was started.
function M.repo_toplevel(dir)
  local out, code = M.git_in(dir or util.project_root(0), { "rev-parse", "--show-toplevel" })
  if code ~= 0 or not out[1] or out[1] == "" then
    vim.notify("git: not inside a git repository", vim.log.levels.WARN)
    return nil
  end
  return out[1]
end

-- Every file changed against the active diff base, as { path, status } with
-- repo-relative paths, sorted by path. At the index base that is git status
-- (staged, unstaged, and untracked); against a ref it is git diff
-- --name-status plus the untracked files, which a diff cannot see but are
-- still part of what this branch changed. Renames report the new path.
function M.changed_files(root)
  local files = {}

  local function add(status, path)
    if path and path ~= "" then
      table.insert(files, { path = path, status = status })
    end
  end

  if base_ref then
    local out, code = M.git_in(root, { "diff", "--name-status", base_ref })
    if code ~= 0 then
      vim.notify("git diff --name-status failed: " .. table.concat(out, "\n"), vim.log.levels.ERROR)
      return nil
    end
    for _, line in ipairs(out) do
      local parts = vim.split(line, "\t", { plain = true })
      add(parts[1], parts[#parts])
    end

    -- Untracked files are invisible to git diff, so list them separately.
    local others, others_code = M.git_in(root, { "ls-files", "--others", "--exclude-standard" })
    if others_code == 0 then
      for _, path in ipairs(others) do
        add("??", path)
      end
    end
  else
    local out, code = M.git_in(root, { "status", "--porcelain" })
    if code ~= 0 then
      vim.notify("git status --porcelain failed: " .. table.concat(out, "\n"), vim.log.levels.ERROR)
      return nil
    end
    for _, line in ipairs(out) do
      local path = line:sub(4)
      add(line:sub(1, 2), path:match("^.* %-> (.*)$") or path)
    end
  end

  table.sort(files, function(a, b)
    return a.path < b.path
  end)
  return files
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

-- Absolute path -> status mark for everything changed against the active base,
-- for decorating file pickers that list far more than the changed files.
function M.status_by_path(dir)
  local root = M.repo_toplevel(dir)
  if not root then
    return {}
  end

  local marks = {}
  for _, file in ipairs(M.changed_files(root) or {}) do
    marks[vim.fs.joinpath(root, file.path)] = M.status_mark(file.status)
  end
  return marks
end

return M
