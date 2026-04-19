return {
  "NeogitOrg/neogit",
  cmd = "Neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  keys = {
    { "<leader>gg", "<cmd>Neogit<cr>", desc = "Status" },
  },
  opts = {
    disable_hint = false,
    graph_style = "unicode",
    integrations = {
      telescope = true,
    },
  },
}
