local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local general = augroup("user_general", { clear = true })
local writing = augroup("user_writing", { clear = true })
local coding = augroup("user_coding", { clear = true })
local utility = augroup("user_utility", { clear = true })

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
  callback = function()
    local opt = vim.opt_local
    opt.tabstop = 2
    opt.softtabstop = 2
    opt.shiftwidth = 2
  end,
})

autocmd("FileType", {
  group = coding,
  pattern = "java",
  callback = function()
    local opt = vim.opt_local
    opt.expandtab = false
    opt.tabstop = 4
    opt.softtabstop = 4
    opt.shiftwidth = 4
  end,
})

autocmd("FileType", {
  group = coding,
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
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
