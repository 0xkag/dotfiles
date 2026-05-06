return {
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
          lualine_a = { "mode" },
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
