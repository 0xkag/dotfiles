-- ~/.config/nvim/lua/plugins/python.lua

return {
  {
    "stevearc/conform.nvim",
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({
            async = true,
            lsp_format = "fallback",
          })
        end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        bash = { "shfmt" },
        go = { "gofmt", "goimports" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettier", stop_after_first = true },
        jsonc = { "prettier", stop_after_first = true },
        lua = { "stylua" },
        markdown = { "prettier", stop_after_first = true },
        python = function(bufnr)
          local conform = require("conform")
          local formatters = {}

          if conform.get_formatter_info("ruff_format", bufnr).available then
            if conform.get_formatter_info("ruff_organize_imports", bufnr).available then
              table.insert(formatters, "ruff_organize_imports")
            end

            table.insert(formatters, "ruff_format")
            return formatters
          end

          for _, formatter in ipairs({ "black", "yapf" }) do
            if conform.get_formatter_info(formatter, bufnr).available then
              return { formatter }
            end
          end

          return {}
        end,
        rust = { "rustfmt" },
        sh = { "shfmt" },
        terraform = { "terraform_fmt" },
        toml = { "taplo" },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettier", stop_after_first = true },
        zsh = { "shfmt" },
      },
    },
  },
  {
    "nvim-neotest/neotest",
    ft = "python",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
      "nvim-neotest/neotest-python",
      "nvim-treesitter/nvim-treesitter",
    },
    keys = {
      {
        "<leader>rr",
        function()
          require("neotest").run.run()
        end,
        desc = "Run nearest test",
      },
      {
        "<leader>rf",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Run file tests",
      },
      {
        "<leader>rR",
        function()
          require("neotest").run.run_last()
        end,
        desc = "Run last test",
      },
      {
        "<leader>rs",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "Toggle test summary",
      },
      {
        "<leader>ro",
        function()
          require("neotest").output.open({ enter = true })
        end,
        desc = "Open test output",
      },
      {
        "<leader>rO",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "Toggle output panel",
      },
      {
        "<leader>rx",
        function()
          require("neotest").run.stop()
        end,
        desc = "Stop test run",
      },
    },
    config = function()
      local python_env = require("config.python")
      local tools = require("config.tools")

      require("neotest").setup({
        adapters = {
          require("neotest-python")({
            python = function()
              return python_env.python_bin(0)
            end,
            runner = function()
              if tools.available("pytest") then
                return "pytest"
              end

              return "unittest"
            end,
          }),
        },
      })

      local group = vim.api.nvim_create_augroup("python_test_keymaps", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "python",
        callback = function(event)
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, {
              buffer = event.buf,
              desc = desc,
              silent = true,
            })
          end

          map("<localleader>tt", function()
            require("neotest").run.run()
          end, "Run nearest test")
          map("<localleader>tf", function()
            require("neotest").run.run(vim.fn.expand("%"))
          end, "Run file tests")
          map("<localleader>tl", function()
            require("neotest").run.run_last()
          end, "Run last test")
          map("<localleader>ts", function()
            require("neotest").summary.toggle()
          end, "Toggle test summary")
          map("<localleader>to", function()
            require("neotest").output.open({ enter = true })
          end, "Open test output")
          map("<localleader>tO", function()
            require("neotest").output_panel.toggle()
          end, "Toggle output panel")
          map("<localleader>tx", function()
            require("neotest").run.stop()
          end, "Stop test run")
        end,
      })
    end,
  },
}
