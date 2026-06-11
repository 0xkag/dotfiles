return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local treesitter = require("nvim-treesitter")
    local parser_config = require("config.treesitter")
    local auto_install = vim.g.nvim_treesitter_auto_install == true

    if type(treesitter.install) == "function" then
      treesitter.setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })

      -- Ensure bundled queries (highlights, injections, etc.) are findable
      -- even when the install step hasn't symlinked them into site/queries/.
      local queries_runtime = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/runtime"
      if not vim.list_contains(vim.opt.rtp:get(), queries_runtime) then
        vim.opt.rtp:prepend(queries_runtime)
      end

      vim.treesitter.language.register("terraform", "tf")
      if auto_install then
        treesitter.install(parser_config.parsers)
      end

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local ft = vim.bo[args.buf].filetype
          local lang = vim.treesitter.language.get_lang(ft)
          if lang and pcall(vim.treesitter.start, args.buf, lang) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
      return
    end

    require("nvim-treesitter.configs").setup({
      auto_install = false,
      ensure_installed = auto_install and parser_config.parsers or {},
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}
