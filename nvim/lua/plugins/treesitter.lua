return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local treesitter = require("nvim-treesitter")
    local parser_config = require("config.treesitter")

    treesitter.setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    -- Ensure bundled queries (highlights, injections, etc.) are findable
    -- even when the install step hasn't symlinked them into site/queries/.
    local queries_runtime = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/runtime"
    if not vim.list_contains(vim.opt.rtp:get(), queries_runtime) then
      vim.opt.rtp:prepend(queries_runtime)
    end

    if vim.g.nvim_treesitter_auto_install == true then
      treesitter.install(parser_config.parsers)
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("nvim-treesitter-attach", { clear = true }),
      callback = function(args)
        parser_config.attach(args.buf)
      end,
    })
  end,
}
