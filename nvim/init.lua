vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local uv = vim.uv or vim.loop
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not uv.fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. output)
  end
end

vim.opt.rtp:prepend(lazypath)

require("config.env")
require("config.options")
require("config.autocmds")
require("config.code_mode").setup()
require("config.python")
require("config.deps")
require("config.projects").setup()
require("config.keymaps")
require("config.theme_review")

require("lazy").setup("plugins", {
  change_detection = { notify = false },
  install = {
    colorscheme = { "cyberdream", "habamax" },
  },
  ui = {
    border = "rounded",
  },
})
