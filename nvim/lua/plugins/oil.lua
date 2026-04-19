local util = require("config.util")

return {
  "stevearc/oil.nvim",
  lazy = false,
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "Oil" },
  keys = {
    { "<leader>od", "<cmd>Oil<cr>", desc = "Directory editor" },
    {
      "<leader>oD",
      function()
        require("oil").open(util.project_root(0))
      end,
      desc = "Project directory editor",
    },
  },
  opts = {
    default_file_explorer = true,
    columns = { "icon" },
    delete_to_trash = false,
    skip_confirm_for_simple_edits = false,
    view_options = {
      show_hidden = true,
      natural_order = "fast",
    },
    keymaps = {
      ["q"] = { "actions.close", mode = "n" },
      ["<Esc>"] = { "actions.close", mode = "n" },
    },
  },
}
