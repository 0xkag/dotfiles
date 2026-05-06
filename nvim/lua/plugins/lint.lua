return {
  "mfussenegger/nvim-lint",
  event = "VeryLazy",
  config = function()
    local lint = require("lint")
    local tools = require("config.tools")

    local function executable(bin)
      return tools.available(bin)
    end

    local function python_linters()
      local linters = {}

      if executable("ruff") then
        table.insert(linters, "ruff")
      end

      if executable("mypy") then
        table.insert(linters, "mypy")
      end

      if #linters == 0 and executable("pylint") then
        table.insert(linters, "pylint")
      end

      if #linters == 0 and executable("flake8") then
        table.insert(linters, "flake8")
      end

      return linters
    end

    local function refresh_linters()
      lint.linters_by_ft = {
        bash = executable("shellcheck") and { "shellcheck" } or {},
        python = python_linters(),
        sh = executable("shellcheck") and { "shellcheck" } or {},
        terraform = executable("tflint") and { "tflint" } or {},
        yaml = executable("yamllint") and { "yamllint" } or {},
        zsh = executable("shellcheck") and { "shellcheck" } or {},
      }
    end

    local lint_group = vim.api.nvim_create_augroup("user_lint", { clear = true })

    local function try_lint()
      refresh_linters()
      lint.try_lint()
    end

    refresh_linters()

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      group = lint_group,
      callback = try_lint,
    })

    vim.keymap.set("n", "<leader>cl", try_lint, {
      desc = "Lint buffer",
      silent = true,
    })

    vim.keymap.set("n", "<leader>cL", function()
      vim.diagnostic.setloclist({ open = true })
    end, {
      desc = "Diagnostics list",
      silent = true,
    })
  end,
}
