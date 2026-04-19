return {
  "stevearc/aerial.nvim",
  cmd = { "AerialOpen", "AerialToggle" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    { "<leader>os", "<cmd>AerialToggle!<cr>", desc = "Symbols outline" },
    {
      "]s",
      function()
        require("aerial").next({ jump = true })
      end,
      desc = "Next symbol",
    },
    {
      "[s",
      function()
        require("aerial").prev({ jump = true })
      end,
      desc = "Previous symbol",
    },
  },
  opts = {
    attach_mode = "window",
    layout = {
      default_direction = "prefer_right",
      min_width = 28,
      resize_to_content = false,
    },
    show_guides = true,
  },
}
