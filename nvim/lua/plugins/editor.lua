return {
  {
    "nvim-mini/mini.nvim",
    version = false,
    event = "VeryLazy",
    dependencies = {
      "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
      require("mini.align").setup()
      require("mini.bufremove").setup()
      require("mini.comment").setup({
        options = {
          ignore_blank_line = true,
          custom_commentstring = function()
            local ok, internal = pcall(require, "ts_context_commentstring.internal")
            if ok then
              return internal.calculate_commentstring() or vim.bo.commentstring
            end
            return vim.bo.commentstring
          end,
        },
      })

      vim.keymap.set({ "n", "x" }, "gl", "ga", {
        remap = true,
        desc = "Align",
        silent = true,
      })
      vim.keymap.set({ "n", "x" }, "gL", "gA", {
        remap = true,
        desc = "Align with preview",
        silent = true,
      })
    end,
  },
  {
    "kylechui/nvim-surround",
    version = "^3.0.0",
    event = "VeryLazy",
    opts = {},
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash jump",
      },
      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash treesitter",
      },
      {
        "r",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Remote flash",
      },
      {
        "R",
        mode = { "o", "x" },
        function()
          require("flash").treesitter_search()
        end,
        desc = "Treesitter search",
      },
      {
        "<leader>jj",
        function()
          require("flash").jump()
        end,
        desc = "Jump",
      },
      {
        "<leader>jt",
        function()
          require("flash").treesitter()
        end,
        desc = "Jump treesitter",
      },
      {
        "<leader>jr",
        function()
          require("flash").remote()
        end,
        desc = "Remote jump",
      },
    },
  },
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {},
    keys = {
      { "<leader>st", "<cmd>TodoTelescope<cr>", desc = "Todo comments" },
    },
  },
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    event = "VeryLazy",
    config = function()
      local mc = require("multicursor-nvim")
      local map = vim.keymap.set

      mc.setup()

      map({ "n", "x" }, "<leader>em", function()
        mc.matchAddCursor(1)
      end, { desc = "Add next match" })
      map({ "n", "x" }, "<leader>eM", function()
        mc.matchAddCursor(-1)
      end, { desc = "Add previous match" })
      map({ "n", "x" }, "<leader>es", function()
        mc.matchSkipCursor(1)
      end, { desc = "Skip next match" })
      map({ "n", "x" }, "<leader>eS", function()
        mc.matchSkipCursor(-1)
      end, { desc = "Skip previous match" })
      map({ "n", "x" }, "<leader>ea", mc.matchAllAddCursors, { desc = "Add all matches" })
      map({ "n", "x" }, "<leader>ej", function()
        mc.lineAddCursor(1)
      end, { desc = "Add cursor below" })
      map({ "n", "x" }, "<leader>ek", function()
        mc.lineAddCursor(-1)
      end, { desc = "Add cursor above" })
      map({ "n", "x" }, "<leader>eJ", function()
        mc.lineSkipCursor(1)
      end, { desc = "Skip line below" })
      map({ "n", "x" }, "<leader>eK", function()
        mc.lineSkipCursor(-1)
      end, { desc = "Skip line above" })
      map({ "n", "x" }, "<leader>eo", mc.addCursorOperator, { desc = "Add cursors by motion" })
      map({ "n", "x" }, "<leader>ec", mc.clearCursors, { desc = "Clear cursors" })
      map({ "n", "x" }, "<C-n>", function()
        mc.matchAddCursor(1)
      end, { desc = "Add next cursor" })

      mc.addKeymapLayer(function(layer)
        layer({ "n", "x" }, "<Left>", mc.prevCursor)
        layer({ "n", "x" }, "<Right>", mc.nextCursor)
        layer({ "n", "x" }, "<Esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)
    end,
  },
}
