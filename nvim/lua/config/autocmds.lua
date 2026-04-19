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
  pattern = "gitcommit",
  callback = function()
    local opt = vim.opt_local
    opt.textwidth = 75
    opt.colorcolumn = "76"
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
  end,
})
