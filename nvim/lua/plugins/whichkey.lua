return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    delay = 300,
    icons = {
      mappings = false,
    },
    preset = "modern",
    spec = {
      { "<leader><tab>", desc = "alternate buffer" },
      { "<leader>b", group = "buffers" },
      { "<leader>c", group = "code" },
      { "<leader>e", group = "edit" },
      { "<leader>f", group = "files" },
      { "<leader>fe", group = "config" },
      { "<leader>g", group = "git" },
      { "<leader>o", group = "open" },
      { "<leader>p", group = "project" },
      { "<leader>q", group = "quit/session" },
      { "<leader>r", group = "run" },
      { "<leader>s", group = "search" },
      { "<leader>t", group = "toggle" },
      { "<leader>w", group = "windows" },
      { "<leader>y", group = "clipboard" },
    },
    win = {
      border = "rounded",
    },
  },
}
