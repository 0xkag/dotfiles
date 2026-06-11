local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local general = augroup("user_general", { clear = true })
local writing = augroup("user_writing", { clear = true })
local coding = augroup("user_coding", { clear = true })
local utility = augroup("user_utility", { clear = true })
local binary = augroup("user_binary", { clear = true })

local function set_indent(width, opts)
  opts = opts or {}

  return function()
    local local_opt = vim.opt_local
    local_opt.expandtab = opts.expandtab ~= false
    local_opt.shiftwidth = width
    local_opt.tabstop = width
    local_opt.softtabstop = width
  end
end

local function blend_signcolumn()
  vim.api.nvim_set_hl(0, "SignColumn", { link = "Normal" })
end

autocmd("ColorScheme", {
  group = general,
  callback = blend_signcolumn,
})

local function link_if_unset(target, source)
  local existing = vim.api.nvim_get_hl(0, { name = target, link = false })
  if next(existing) == nil then
    vim.api.nvim_set_hl(0, target, { link = source })
  end
end

local function apply_cmp_fallbacks()
  link_if_unset("CmpItemAbbr", "Pmenu")
  link_if_unset("CmpItemAbbrDeprecated", "Comment")
  link_if_unset("CmpItemAbbrMatch", "Search")
  link_if_unset("CmpItemAbbrMatchFuzzy", "IncSearch")
  link_if_unset("CmpItemMenu", "Comment")
  link_if_unset("CmpItemKindFunction", "Function")
  link_if_unset("CmpItemKindMethod", "Function")
  link_if_unset("CmpItemKindVariable", "Identifier")
  link_if_unset("CmpItemKindField", "Identifier")
  link_if_unset("CmpItemKindClass", "Type")
  link_if_unset("CmpItemKindInterface", "Type")
  link_if_unset("CmpItemKindStruct", "Type")
  link_if_unset("CmpItemKindModule", "PreProc")
  link_if_unset("CmpItemKindKeyword", "Keyword")
  link_if_unset("CmpItemKindSnippet", "String")
  link_if_unset("CmpItemKindText", "Normal")
  link_if_unset("CmpItemKindProperty", "Constant")
  link_if_unset("CmpItemKindConstant", "Constant")
  link_if_unset("LspSignatureActiveParameter", "Search")
  link_if_unset("@markup.raw.markdown", "NormalFloat")
  link_if_unset("@markup.raw.block.markdown", "NormalFloat")
  link_if_unset("@markup.raw.delimiter.markdown", "NormalFloat")
end

autocmd("ColorScheme", {
  group = general,
  callback = apply_cmp_fallbacks,
})

apply_cmp_fallbacks()

autocmd("TextYankPost", {
  group = general,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

autocmd({ "BufRead", "BufNewFile" }, {
  group = general,
  pattern = "*.cls",
  callback = function()
    vim.bo.filetype = "java"
  end,
})

autocmd("VimEnter", {
  group = general,
  callback = blend_signcolumn,
})

autocmd({ "BufRead", "BufNewFile" }, {
  group = general,
  pattern = "*.tftpl",
  callback = function()
    vim.bo.filetype = "terraform"
  end,
})

autocmd({ "BufRead", "BufNewFile" }, {
  group = general,
  pattern = "*.zsh-theme",
  callback = function()
    vim.bo.filetype = "zsh"
  end,
})

autocmd("FileType", {
  group = writing,
  pattern = { "gitcommit", "markdown", "org", "text" },
  callback = function()
    local opt = vim.opt_local
    opt.wrap = true
    opt.linebreak = true
    opt.breakindent = true
    opt.spell = true
    opt.conceallevel = 2
  end,
})

autocmd("FileType", {
  group = writing,
  pattern = { "gitcommit", "gitrebase" },
  callback = function()
    local opt = vim.opt_local
    opt.textwidth = 75
    opt.colorcolumn = "76"
    -- The built-in gitcommit ftplugin sets `formatoptions+=tl`. The `l` flag
    -- suppresses auto-wrap on any line that was already longer than textwidth
    -- when insert started -- which is exactly the pre-filled body of an amended
    -- commit. That makes textwidth look ignored on `--amend` while a fresh
    -- commit (short lines you type from scratch) wraps fine. Drop `l` so long
    -- pre-existing lines reflow to textwidth as they are edited.
    opt.formatoptions:remove("l")
  end,
})

autocmd("FileType", {
  group = coding,
  pattern = { "bash", "sh", "zsh" },
  callback = set_indent(2),
})

autocmd("FileType", {
  group = coding,
  pattern = {
    "css",
    "html",
    "javascript",
    "javascriptreact",
    "json",
    "jsonc",
    "lua",
    "markdown",
    "terraform",
    "toml",
    "typescript",
    "typescriptreact",
    "yaml",
  },
  callback = set_indent(2),
})

autocmd("FileType", {
  group = coding,
  pattern = { "c", "cpp", "python", "rust" },
  callback = set_indent(4),
})

autocmd("FileType", {
  group = coding,
  pattern = "go",
  callback = set_indent(4, { expandtab = false }),
})

autocmd("FileType", {
  group = coding,
  pattern = "java",
  callback = set_indent(4, { expandtab = false }),
})

autocmd("FileType", {
  group = coding,
  pattern = "make",
  callback = function()
    local opt = vim.opt_local
    opt.expandtab = false
    opt.shiftwidth = 4
    opt.tabstop = 4
    opt.softtabstop = 4
  end,
})

autocmd({ "BufReadPre", "BufNewFile" }, {
  group = binary,
  pattern = "*.bin",
  callback = function(event)
    if vim.fn.executable("xxd") ~= 1 then
      vim.notify("Install xxd to use binary editing for *.bin files.", vim.log.levels.WARN)
      return
    end

    vim.bo[event.buf].binary = true
  end,
})

autocmd("BufReadPost", {
  group = binary,
  pattern = "*.bin",
  callback = function(event)
    if not vim.bo[event.buf].binary or vim.fn.executable("xxd") ~= 1 then
      return
    end

    vim.cmd("%!xxd")
    vim.bo[event.buf].filetype = "xxd"
  end,
})

autocmd("BufWritePre", {
  group = binary,
  pattern = "*.bin",
  callback = function(event)
    if not vim.bo[event.buf].binary or vim.fn.executable("xxd") ~= 1 then
      return
    end

    vim.cmd("%!xxd -r")
  end,
})

autocmd("BufWritePost", {
  group = binary,
  pattern = "*.bin",
  callback = function(event)
    if not vim.bo[event.buf].binary or vim.fn.executable("xxd") ~= 1 then
      return
    end

    vim.cmd("%!xxd")
    vim.bo[event.buf].modified = false
  end,
})

autocmd("FileType", {
  group = utility,
  pattern = {
    "aerial",
    "checkhealth",
    "help",
    "lazy",
    "lspinfo",
    "man",
    "mason",
    "neotest-summary",
    "qf",
    "startuptime",
    "TelescopePrompt",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<Cmd>close<CR>", {
      buffer = event.buf,
      desc = "Close window",
      silent = true,
    })
    vim.keymap.set("n", "<Esc>", "<Cmd>close<CR>", {
      buffer = event.buf,
      desc = "Close window",
      silent = true,
    })
    vim.keymap.set("n", "<C-g>", "<Cmd>close<CR>", {
      buffer = event.buf,
      desc = "Close window",
      silent = true,
    })
  end,
})

autocmd("FileType", {
  group = utility,
  pattern = "neo-tree",
  callback = function(event)
    vim.opt_local.signcolumn = "auto"
    vim.keymap.set("n", "q", "<Cmd>Neotree close<CR>", {
      buffer = event.buf,
      desc = "Close explorer",
      silent = true,
    })
    vim.keymap.set("n", "<Esc>", "<Cmd>Neotree close<CR>", {
      buffer = event.buf,
      desc = "Close explorer",
      silent = true,
    })
    vim.keymap.set("n", "<C-g>", "<Cmd>Neotree close<CR>", {
      buffer = event.buf,
      desc = "Close explorer",
      silent = true,
    })
  end,
})
