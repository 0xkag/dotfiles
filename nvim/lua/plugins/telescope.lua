local util = require("config.util")

return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  keys = {
    {
      "<leader>bb",
      function()
        require("telescope.builtin").buffers()
      end,
      desc = "Switch buffer",
    },
    {
      "<leader>ff",
      function()
        util.find_files({
          cwd = util.cwd(),
          title = "Files",
        })
      end,
      desc = "Find files",
    },
    { "<leader>fd", util.dotfiles, desc = "Find dotfiles" },
    {
      "<leader>fr",
      function()
        require("telescope.builtin").oldfiles()
      end,
      desc = "Recent files",
    },
    {
      "<leader>fh",
      function()
        require("telescope.builtin").help_tags()
      end,
      desc = "Help tags",
    },
    { "<leader>pf", util.project_files, desc = "Project files" },
    { "<leader>pg", util.project_grep, desc = "Project grep" },
    {
      "<leader>ss",
      function()
        require("telescope.builtin").current_buffer_fuzzy_find()
      end,
      desc = "Search buffer",
    },
    { "<leader>sg", util.cwd_grep, desc = "Search cwd" },
    {
      "<leader>sw",
      function()
        require("telescope.builtin").grep_string({
          search = vim.fn.expand("<cword>"),
        })
      end,
      desc = "Search word",
    },
    {
      "<leader>sd",
      function()
        require("telescope.builtin").diagnostics()
      end,
      desc = "Search diagnostics",
    },
  },
  opts = function()
    local actions = require("telescope.actions")

    return {
      defaults = {
        file_ignore_patterns = {
          "%.git/",
          "node_modules/",
          "%.mypy_cache/",
          "%.pytest_cache/",
        },
        layout_config = {
          prompt_position = "top",
        },
        layout_strategy = "horizontal",
        mappings = {
          i = {
            ["<C-h>"] = "which_key",
            ["<Esc>"] = actions.close,
          },
          n = {
            ["q"] = actions.close,
          },
        },
        sorting_strategy = "ascending",
      },
      pickers = {
        buffers = {
          ignore_current_buffer = true,
          sort_mru = true,
        },
        find_files = {
          hidden = true,
        },
      },
    }
  end,
}
