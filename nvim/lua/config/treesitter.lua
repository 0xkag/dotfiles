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

local parser_by_filetype = {
  bash = "bash",
  c = "c",
  cpp = "cpp",
  css = "css",
  diff = "diff",
  dockerfile = "dockerfile",
  go = "go",
  gomod = "gomod",
  html = "html",
  javascript = "javascript",
  javascriptreact = "tsx",
  json = "json",
  lua = "lua",
  make = "make",
  markdown = "markdown",
  python = "python",
  rust = "rust",
  sh = "bash",
  sql = "sql",
  terraform = "terraform",
  toml = "toml",
  typescript = "typescript",
  typescriptreact = "tsx",
  vim = "vim",
  yaml = "yaml",
  zsh = "bash",
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

function M.parser_for_filetype(ft)
  if not ft or ft == "" then
    return nil
  end

  if vim.treesitter and vim.treesitter.language and vim.treesitter.language.get_lang then
    local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
    if ok and lang and lang ~= "" then
      return lang
    end
  end

  return parser_by_filetype[ft]
end

function M.missing_for_filetype(ft)
  local lang = M.parser_for_filetype(ft)
  if not lang or parser_installed(lang) then
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
