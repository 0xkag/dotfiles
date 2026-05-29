local completion = require("config.completion")

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_cmp_disable", { clear = true }),
  pattern = { "gitcommit" },
  callback = function(event)
    vim.b[event.buf].cmp_disabled = true
  end,
})

return {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-path",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
  },
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")

    completion.configure_cmp(cmp, luasnip)
  end,
}
