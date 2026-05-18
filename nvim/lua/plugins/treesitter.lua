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
