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
