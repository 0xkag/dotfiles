return {
  "mistweaverco/kulala.nvim",
  ft = { "http", "rest" },
  opts = {
    global_keymaps = false,
  },
  config = function(_, opts)
    require("kulala").setup(opts)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "http", "rest" },
      callback = function(event)
        local map = require("config.code_mode.shared").buf_map(event.buf)

        map("n", "<localleader>r", function()
          require("kulala").run()
        end, "Run request")
        map("n", "<localleader>a", function()
          require("kulala").run_all()
        end, "Run all requests")
        map("n", "<localleader>l", function()
          require("kulala").replay()
        end, "Replay last request")
        map("n", "<localleader>o", function()
          require("kulala").open()
        end, "Open response")
        map("n", "<localleader>i", function()
          require("kulala").inspect()
        end, "Inspect request")
        map("n", "<localleader>s", function()
          require("kulala").show_stats()
        end, "Show stats")

        -- `,r`, `,a` and `,i` share their key with the global refactor, action
        -- and insert/import groups, whose label which-key would show instead.
        require("config.code_mode.shared").register_git_editor_labels(event.buf, {
          { "<localleader>a", desc = "run all requests", buffer = event.buf },
          { "<localleader>i", desc = "inspect request", buffer = event.buf },
          { "<localleader>r", desc = "run request", buffer = event.buf },
        })
      end,
    })
  end,
}
