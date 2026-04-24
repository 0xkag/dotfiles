-- ~/.config/nvim/lua/plugins/treesitter.lua

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  main = "nvim-treesitter.configs",
  opts = {
    auto_install = false,
    highlight = {
      enable = true,
    },
    indent = {
      enable = true,
      disable = { "markdown", "python" },
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn",
        node_decremental = "grm",
        node_incremental = "grn",
        scope_incremental = "grc",
      },
    },
  },
}
