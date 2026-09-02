-- Which nvim-lint linters a filetype gets. Pure: availability is a predicate
-- the caller supplies (config.tools.available in practice), so lint.lua can
-- resolve one filetype right before linting it instead of rebuilding every
-- filetype's list on each read and write of any buffer.
local M = {}

-- Candidates in preference order; the first one available is used. Ruff is
-- absent from the Python list on purpose: its diagnostics come from the ruff
-- LSP server (see lsp.lua), and running it here too would duplicate them.
local candidates_by_ft = {
  bash = { "shellcheck" },
  python = { "mypy", "pylint", "flake8" },
  sh = { "shellcheck" },
  terraform = { "tflint" },
  yaml = { "yamllint" },
  zsh = { "shellcheck" },
}

-- The linters for `ft`: a one-element list, an empty list when none of its
-- candidates is available, or nil for a filetype with no linters configured so
-- the caller can leave nvim-lint's table untouched for it.
function M.for_filetype(ft, available)
  local candidates = candidates_by_ft[ft]
  if not candidates then
    return nil
  end

  for _, bin in ipairs(candidates) do
    if available(bin) then
      return { bin }
    end
  end
  return {}
end

-- Every filetype with linters configured, sorted.
function M.filetypes()
  local filetypes = vim.tbl_keys(candidates_by_ft)
  table.sort(filetypes)
  return filetypes
end

return M
