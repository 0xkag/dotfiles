local M = {}

M.parsers = {
  "bash",
  "c",
  "cpp",
  "css",
  "diff",
  "dockerfile",
  "go",
  "gomod",
  "gosum",
  "html",
  "javascript",
  "json",
  "lua",
  "luadoc",
  "luap",
  "make",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "regex",
  "rust",
  "sql",
  "terraform",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

local function parser_installed(lang)
  if not lang or lang == "" then
    return true
  end

  if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", false) > 0 then
    return true
  end

  if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".dll", false) > 0 then
    return true
  end

  if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".dylib", false) > 0 then
    return true
  end

  return false
end

-- Neovim's own filetype -> language mapping, which nvim-treesitter extends
-- with its registrations at runtime. It never returns nil for a filetype: one
-- nothing registered maps to itself.
function M.parser_for_filetype(ft)
  if not ft or ft == "" then
    return nil
  end

  return vim.treesitter.language.get_lang(ft)
end

-- The parser `ft` needs and does not have, as a list. Only a language this
-- config lists can be missing: a filetype with no parser anywhere (tftpl, which
-- syntax/tftpl.vim highlights) maps to itself and must not be reported as
-- missing a parser that does not exist.
function M.missing_for_filetype(ft)
  local lang = M.parser_for_filetype(ft)
  if not lang or not vim.list_contains(M.parsers, lang) or parser_installed(lang) then
    return {}
  end

  return { lang }
end

-- Start treesitter for `bufnr` if its filetype has a parser, and only then mark
-- the buffer for treesitter folding and hand its indent to treesitter. Returns
-- whether treesitter started.
--
-- The mark is a buffer variable rather than a window option on purpose: a
-- window-local 'foldmethod' set here stays with the window and every later
-- buffer shown in it inherits it, parser or not. The global 'foldexpr' consults
-- the mark instead (see M.foldexpr).
function M.attach(bufnr)
  local lang = M.parser_for_filetype(vim.bo[bufnr].filetype)
  if not lang or not pcall(vim.treesitter.start, bufnr, lang) then
    return false
  end

  vim.b[bufnr].ts_folds = true
  vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  return true
end

-- The global 'foldexpr': treesitter folds for a buffer attach() marked, and "0"
-- for every other buffer. vim.treesitter.foldexpr() on its own looks a parser
-- up per line for a buffer that has none, which is what a huge generated file
-- used to pay on every redraw.
function M.foldexpr(lnum)
  if not vim.b[vim.api.nvim_get_current_buf()].ts_folds then
    return "0"
  end
  return vim.treesitter.foldexpr(lnum)
end

function M.missing_configured()
  local missing = {}
  for _, lang in ipairs(M.parsers) do
    if not parser_installed(lang) then
      table.insert(missing, lang)
    end
  end
  return missing
end

return M
