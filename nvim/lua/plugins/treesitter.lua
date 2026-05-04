return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    local parsers = {
      "bash", "c", "cpp", "css", "diff", "dockerfile", "go", "gomod",
      "gosum", "html", "javascript", "json", "lua", "luadoc",
      "luap", "make", "markdown", "markdown_inline", "python",
      "query", "regex", "rust", "sql", "terraform", "toml", "tsx",
      "typescript", "vim", "vimdoc", "yaml",
    }
    require("nvim-treesitter").install(parsers)

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if lang and pcall(vim.treesitter.start, args.buf, lang) then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
