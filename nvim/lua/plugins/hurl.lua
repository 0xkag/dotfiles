-- HTTP requests from `.hurl` files, run by the hurl CLI (mise). The requests
-- are hurl's plain-text format, so the same file runs from the shell or CI
-- without the editor. Responses open in a split; JSON goes through jq, and
-- hurl.nvim skips a formatter that is not installed (prettier, tidy).
return {
  "jellydn/hurl.nvim",
  ft = "hurl",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    mode = "split",
  },
  config = function(_, opts)
    require("hurl").setup(opts)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "hurl",
      callback = function(event)
        local shared = require("config.code_mode.shared")
        local map = shared.buf_map(event.buf)

        map("n", "<localleader>r", "<cmd>HurlRunnerAt<CR>", "Run request")
        map("x", "<localleader>r", ":HurlRunner<CR>", "Run selected requests")
        map("n", "<localleader>a", "<cmd>HurlRunner<CR>", "Run all requests")
        map("n", "<localleader>e", "<cmd>HurlRunnerToEntry<CR>", "Run requests up to here")
        map("n", "<localleader>E", "<cmd>HurlRunnerToEnd<CR>", "Run requests from here to end")
        map("n", "<localleader>l", "<cmd>HurlShowLastResponse<CR>", "Show last response")
        map("n", "<localleader>v", "<cmd>HurlVerbose<CR>", "Run request verbose")
        map("n", "<localleader>V", "<cmd>HurlVeryVerbose<CR>", "Run request very verbose")
        map("n", "<localleader>m", "<cmd>HurlToggleMode<CR>", "Toggle split/popup response")
        map("n", "<localleader>s", "<cmd>HurlSelectEnvFile<CR>", "Select env file")

        -- `,r`, `,a` and `,e` share their key with the global refactor, action
        -- and errors/exec groups, whose label which-key would show instead.
        shared.register_git_editor_labels(event.buf, {
          { "<localleader>a", desc = "run all requests", buffer = event.buf },
          { "<localleader>e", desc = "run requests up to here", buffer = event.buf },
          { "<localleader>r", desc = "run request", buffer = event.buf },
        })
      end,
    })
  end,
}
