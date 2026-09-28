vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
-- No remote plugins here need the language hosts; off, they stop probing for
-- the neovim npm/cpan/pip/gem packages and :checkhealth stops warning.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

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

-- Load order matters: env sets PATH before anything spawns tools; options/
-- autocmds establish editor state; code_mode.setup() registers its FileType
-- autocmds before keymaps so its localleader which-key labels are in place;
-- python/deps/projects wire side effects; then lazy loads the plugin specs.
require("config.env")
require("config.ansible").setup()
require("config.options")
require("config.autocmds")
require("config.code_mode").setup()
require("config.python")
require("config.deps")
require("config.projects").setup()
require("config.diagnostic_float").setup()
require("config.keymaps")
require("config.theme_review")

require("lazy").setup("plugins", {
  change_detection = { notify = false },
  install = {
    colorscheme = { "cyberpunk", "cyberdream", "habamax" },
  },
  ui = {
    border = "rounded",
  },
})
