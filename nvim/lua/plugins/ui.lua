return {
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 900,
    opts = {
      input = { enabled = true },
      -- A file over 1.5 MB, or averaging over 1000 bytes a line, gets the
      -- `bigfile` filetype before FileType fires, so the treesitter hook and
      -- the LSP servers never see it; syntax falls back to the regex kind.
      -- Measured on a 3.2 MB Lua table: 2.2 s to open and 1.7 s per redraw
      -- with treesitter attached.
      bigfile = { enabled = true },
      dashboard = { enabled = false },
      notifier = { enabled = false },
      quickfile = { enabled = false },
      scroll = { enabled = false },
      statuscolumn = { enabled = false },
      words = { enabled = false },
    },
  },
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
    config = function(_, opts)
      require("cyberdream").setup(opts)
      vim.cmd.colorscheme("cyberpunk")
    end,
  },
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      local cyberpunk_theme = {
        normal = {
          a = { fg = "#000000", bg = "#4c83ff", gui = "bold" },
          b = { fg = "#d3d3d3", bg = "#333333" },
          c = { fg = "#d3d3d3", bg = "#000000" },
        },
        insert = { a = { fg = "#000000", bg = "#61ce3c", gui = "bold" } },
        visual = { a = { fg = "#000000", bg = "#ff1493", gui = "bold" } },
        replace = { a = { fg = "#000000", bg = "#ffa500", gui = "bold" } },
        command = { a = { fg = "#000000", bg = "#ffff00", gui = "bold" } },
        inactive = {
          a = { fg = "#6f6f6f", bg = "#1a1a1a" },
          b = { fg = "#6f6f6f", bg = "#1a1a1a" },
          c = { fg = "#6f6f6f", bg = "#1a1a1a" },
        },
      }
      return {
        options = {
          component_separators = { left = "|", right = "|" },
          globalstatus = true,
          section_separators = { left = "", right = "" },
          theme = cyberpunk_theme,
        },
        sections = {
          lualine_a = {
            "mode",
            {
              function()
                return "MC:" .. require("multicursor-nvim").numCursors()
              end,
              cond = function()
                local ok, mc = pcall(require, "multicursor-nvim")
                return ok and mc.hasCursors()
              end,
            },
          },
          lualine_b = { "branch", "diff" },
          lualine_c = {
            {
              "filename",
              path = 1,
            },
          },
          lualine_x = { "diagnostics", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        extensions = { "neo-tree", "quickfix" },
      }
    end,
  },
}
