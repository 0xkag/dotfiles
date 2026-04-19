return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {
    branch = true,
  },
  keys = {
    {
      "<leader>qs",
      function()
        require("persistence").load()
      end,
      desc = "Restore session",
    },
    {
      "<leader>qS",
      function()
        require("persistence").select()
      end,
      desc = "Select session",
    },
    {
      "<leader>ql",
      function()
        require("persistence").load({ last = true })
      end,
      desc = "Restore last session",
    },
    {
      "<leader>qd",
      function()
        require("persistence").stop()
      end,
      desc = "Stop session saving",
    },
    {
      "<leader>qr",
      function()
        require("persistence").start()
      end,
      desc = "Resume session saving",
    },
    {
      "<leader>qW",
      function()
        require("persistence").save()
      end,
      desc = "Save session now",
    },
  },
}
