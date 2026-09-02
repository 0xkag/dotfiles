return {
  "mfussenegger/nvim-lint",
  event = "VeryLazy",
  config = function()
    local lint = require("lint")
    local linters = require("config.linters")
    local tools = require("config.tools")

    -- The built-in tflint linter runs `tflint --recursive`, scanning the whole
    -- repo on every buffer read/save; in a large repo, editing several files
    -- spawns many concurrent full-repo scans that saturate the CPU. Scope each
    -- run to the edited file's module instead (see config.tflint). nvim-lint
    -- calls a function-valued linter per run, so the cwd follows the buffer.
    local upstream_tflint = require("lint.linters.tflint")
    lint.linters.tflint = function()
      return require("config.tflint").linter(upstream_tflint, vim.api.nvim_buf_get_name(0))
    end

    local lint_group = vim.api.nvim_create_augroup("user_lint", { clear = true })

    -- Resolve the linters for the buffer's filetype right before linting it,
    -- against the session's cached tool probes (config.linters, config.tools).
    -- The old code rebuilt every filetype's list, probing all seven tools, on
    -- each read and write of any buffer.
    local function try_lint()
      local ft = vim.bo.filetype
      local selected = linters.for_filetype(ft, tools.available)
      if selected then
        lint.linters_by_ft[ft] = selected
      end
      lint.try_lint()
    end

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      group = lint_group,
      callback = try_lint,
    })

    vim.keymap.set("n", "<leader>el", try_lint, {
      desc = "Lint buffer",
      silent = true,
    })

    vim.keymap.set("n", "<leader>eL", function()
      vim.diagnostic.setloclist({ open = true })
    end, {
      desc = "Error loclist",
      silent = true,
    })
  end,
}
