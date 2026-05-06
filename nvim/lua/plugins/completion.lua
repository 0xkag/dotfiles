vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_cmp_disable", { clear = true }),
  pattern = { "gitcommit" },
  callback = function(event)
    vim.b[event.buf].cmp_disabled = true
  end,
})

vim.keymap.set("n", "<leader>ta", function()
  local buf = vim.api.nvim_get_current_buf()
  vim.b[buf].cmp_disabled = not vim.b[buf].cmp_disabled
  vim.notify(
    "Auto-completion " .. (vim.b[buf].cmp_disabled and "disabled" or "enabled") .. " for this buffer.",
    vim.log.levels.INFO
  )
end, { desc = "Toggle auto-completion (buffer)" })

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

    cmp.setup({
      enabled = function()
        local buf = vim.api.nvim_get_current_buf()
        if vim.b[buf].cmp_disabled then
          return false
        end
        return vim.bo[buf].buftype ~= "prompt"
      end,
      completion = {
        completeopt = "menu,menuone,noselect",
      },
      experimental = {
        ghost_text = true,
      },
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<Esc>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.abort()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_locally_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.locally_jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      }),
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "path" },
      }, {
        { name = "buffer" },
      }),
      window = {
        documentation = cmp.config.window.bordered(),
      },
    })
  end,
}
