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
        local map = function(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, {
            buffer = event.buf,
            desc = desc,
            silent = true,
          })
        end

        map("<localleader>r", function()
          require("kulala").run()
        end, "Run request")
        map("<localleader>a", function()
          require("kulala").run_all()
        end, "Run all requests")
        map("<localleader>l", function()
          require("kulala").replay()
        end, "Replay last request")
        map("<localleader>o", function()
          require("kulala").open()
        end, "Open response")
        map("<localleader>i", function()
          require("kulala").inspect()
        end, "Inspect request")
        map("<localleader>s", function()
          require("kulala").show_stats()
        end, "Show stats")
      end,
    })
  end,
}
