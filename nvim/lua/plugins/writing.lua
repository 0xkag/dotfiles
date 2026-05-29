return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    opts = {
      org_agenda_files = {
        "~/wc/personal/personal/*.org",
        "~/.dotfiles/_sites/current/*.org",
      },
      org_default_notes_file = "~/wc/personal/personal/todo.org",
      org_todo_keywords = {
        "TODO(t)",
        "TODELEGATE(g)",
        "DELEGATED(e)",
        "DOING(i)",
        "DEFERRED(f)",
        "WAITING(w)",
        "VERIFY(v)",
        "|",
        "DONE(d)",
        "WONTFIX(x)",
      },
    },
    config = function(_, opts)
      require("orgmode").setup(opts)
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "gitcommit", "markdown", "org" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      file_types = { "gitcommit", "markdown", "org" },
      ignore = function(buf)
        for _, win in ipairs(vim.fn.win_findbuf(buf)) do
          if vim.api.nvim_win_get_config(win).relative ~= "" then
            return true
          end
        end
        return false
      end,
    },
  },
}
