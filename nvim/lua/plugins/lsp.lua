-- ~/.config/nvim/lua/plugins/lsp.lua

return {
  {
    "smjonas/inc-rename.nvim",
    event = "LspAttach",
    opts = {
      cmd_name = "IncRename",
      hl_group = "Substitute",
      preview_empty_name = false,
      show_message = true,
    },
  },
  {
    "mason-org/mason.nvim",
    cmd = {
      "Mason",
      "MasonInstall",
      "MasonLog",
      "MasonUninstall",
      "MasonUninstallAll",
      "MasonUpdate",
    },
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = "VeryLazy",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      -- Bound a runaway loop in Neovim's semantic-tokens highlighter that a
      -- malformed token field (a wrapped-negative deltaStart seen from
      -- terraform-ls) can otherwise spin forever on the main thread.
      require("config.lsp_semantic_guard").apply()

      vim.diagnostic.config({
        float = { border = "rounded" },
        severity_sort = true,
        signs = true,
        underline = true,
        virtual_text = false,
      })

      -- Every server gets cmp's completion capabilities through the "*"
      -- config; tables merge, so a server's own additions would survive.
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })

      -- The file-watch guard declines the recursive watcher when the
      -- pure-Lua watchdirs backend would otherwise walk a huge workspace on
      -- the main thread; it no-ops unless that exact condition holds. It
      -- cannot ride on "*": vim.lsp.config merges "*", nvim-lspconfig's
      -- lsp/<name>.lua and this table with a plain deep-extend, so a function
      -- at any later layer replaces an earlier one rather than composing with
      -- it. So it is composed into each server's on_init here, ahead of the
      -- server's own (pylsp's capability strip).
      local lsp_watch = require("config.lsp_watch")
      local function with_watch_guard(on_init)
        return function(client, init_result)
          lsp_watch.maybe_suppress(client)
          if on_init then
            on_init(client, init_result)
          end
        end
      end

      local lsp_servers = require("config.lsp_servers")
      for name, server in pairs(lsp_servers.servers) do
        vim.lsp.config(name, vim.tbl_extend("force", server, {
          on_init = with_watch_guard(server.on_init),
        }))
      end
      vim.lsp.enable(lsp_servers.names())

      require("config.lsp_keymaps").setup()

      vim.api.nvim_create_autocmd("LspDetach", {
        group = vim.api.nvim_create_augroup("user_lsp_watch", { clear = true }),
        callback = function(event)
          lsp_watch.cleanup(event.data.client_id)
        end,
      })
    end,
  },
}
