local util = require("config.util")

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  cmd = "Neotree",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    { "<leader>oe", "<cmd>Neotree toggle<cr>", desc = "Explorer toggle" },
    { "<leader>oE", "<cmd>Neotree reveal<cr>", desc = "Reveal current file" },
    { "<leader>ft", "<cmd>Neotree toggle<cr>", desc = "File tree toggle" },
    { "<leader>fT", "<cmd>Neotree reveal<cr>", desc = "Reveal current file" },
    {
      "<leader>pe",
      function()
        vim.cmd("Neotree reveal dir=" .. vim.fn.fnameescape(util.project_root(0)))
      end,
      desc = "Project explorer",
    },
    {
      "<leader>pt",
      function()
        vim.cmd("Neotree reveal dir=" .. vim.fn.fnameescape(util.project_root(0)))
      end,
      desc = "Project tree",
    },
  },
  opts = {
    close_if_last_window = false,
    filesystem = {
      follow_current_file = {
        enabled = true,
      },
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      hijack_netrw_behavior = "open_current",
      use_libuv_file_watcher = true,
    },
    window = {
      width = 32,
    },
  },
}
