-- A module-scoped tflint linter for nvim-lint.
--
-- nvim-lint's own tflint definition runs `tflint --recursive`, which scans the
-- whole repo on every buffer read and save; editing a few files in a large repo
-- spawns that many concurrent full-repo scans and saturates the CPU. tflint
-- lints the module in its cwd when told nothing else, so running it with the
-- edited file's directory as the process cwd scopes it to that module for free.
--
-- The scope used to be `--chdir=<absolute dir> --filter=<basename>`, which
-- reported nothing at all: tflint matches --filter against paths relative to
-- its own cwd, and with an absolute --chdir no path ever matched. Scoping by
-- cwd needs no filter; the parser drops issues from the module's other files.
local M = {}

local severities = {
  error = vim.diagnostic.severity.ERROR,
  notice = vim.diagnostic.severity.INFO,
  warning = vim.diagnostic.severity.WARN,
}

-- The directory tflint should run in for a buffer: the one holding its file.
function M.module_dir(bufname)
  return vim.fn.fnamemodify(bufname, ":p:h")
end

local function absolute(path, cwd)
  if path:sub(1, 1) ~= "/" then
    path = vim.fs.joinpath(cwd, path)
  end
  return vim.fs.normalize(path)
end

-- tflint's JSON report -> vim.Diagnostic list for `bufnr`. Issue filenames are
-- relative to the directory the process ran in, which nvim-lint passes as
-- `cwd`. HCL ranges are 1-based with an exclusive end column; vim.Diagnostic is
-- 0-based, so the start and end both shift down by one and the end stays
-- exclusive.
function M.parse(output, bufnr, cwd)
  local ok, decoded = pcall(vim.json.decode, output)
  if not ok or type(decoded) ~= "table" then
    return {}
  end

  local buf_path = absolute(vim.api.nvim_buf_get_name(bufnr), cwd)
  local diagnostics = {}

  for _, issue in ipairs(decoded.issues or {}) do
    local range = issue.range or {}
    if range.filename and absolute(range.filename, cwd) == buf_path then
      local rule = issue.rule or {}
      table.insert(diagnostics, {
        col = (range.start.column or 1) - 1,
        end_col = (range["end"].column or 1) - 1,
        end_lnum = (range["end"].line or 1) - 1,
        lnum = (range.start.line or 1) - 1,
        message = string.format("%s (%s)\nReference: %s", issue.message, rule.name, rule.link),
        severity = severities[rule.severity] or vim.diagnostic.severity.WARN,
        source = "tflint",
      })
    end
  end

  return diagnostics
end

-- The upstream linter definition, rescoped to the module holding `bufname`.
-- nvim-lint accepts a function in place of a linter table and calls it per
-- run, so lint.lua registers `function() return linter(upstream, <buf>) end`
-- and the cwd tracks the current buffer.
function M.linter(upstream, bufname)
  local linter = vim.deepcopy(upstream)
  linter.args = { "--format=json" }
  linter.cwd = M.module_dir(bufname)
  linter.parser = M.parse
  return linter
end

return M
