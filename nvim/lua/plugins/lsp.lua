-- ~/.config/nvim/lua/plugins/lsp.lua

return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "mason-org/mason-lspconfig.nvim",
      "mason-org/mason.nvim",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local servers = {
        ansiblels = {},
        bashls = {},
        clangd = {},
        cssls = {},
        dockerls = {},
        gopls = {},
        html = {},
        jdtls = {},
        jsonls = {},
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = "Replace",
              },
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                checkThirdParty = false,
                library = vim.api.nvim_get_runtime_file("", true),
              },
            },
          },
        },
        marksman = {},
        pyright = {
          settings = {
            python = {
              analysis = {
                autoSearchPaths = true,
                diagnosticMode = "workspace",
                exclude = {
                  "**/.mypy_cache",
                  "**/.pytest_cache",
                  "**/veritas-config/**",
                },
                useLibraryCodeForTypes = true,
              },
            },
          },
        },
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
              },
            },
          },
        },
        taplo = {},
        terraformls = {
          cmd = { "terraform-ls", "serve" },
        },
        ts_ls = {},
        yamlls = {
          settings = {
            yaml = {
              keyOrdering = false,
            },
          },
        },
      }

      vim.diagnostic.config({
        float = { border = "rounded" },
        severity_sort = true,
        signs = true,
        underline = true,
        virtual_text = false,
      })

      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      vim.keymap.set("n", "<leader>ce", vim.diagnostic.open_float, { desc = "Line diagnostics" })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local builtin = require("telescope.builtin")
          local bufnr = event.buf
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, {
              buffer = bufnr,
              desc = desc,
              silent = true,
            })
          end

          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("gr", builtin.lsp_references, "References")
          map("K", vim.lsp.buf.hover, "Hover")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>cd", function()
            builtin.diagnostics({ bufnr = 0 })
          end, "Buffer diagnostics")
          map("<leader>cs", builtin.lsp_document_symbols, "Document symbols")
          map("<leader>cS", builtin.lsp_dynamic_workspace_symbols, "Workspace symbols")

          if vim.lsp.inlay_hint then
            map("<leader>ch", function()
              local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
              vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
            end, "Toggle inlay hints")
          end
        end,
      })

      for name, config in pairs(servers) do
        config.capabilities = vim.tbl_deep_extend("force", {}, capabilities, config.capabilities or {})
        vim.lsp.config(name, config)
        vim.lsp.enable(name)
      end

      require("mason-lspconfig").setup({
        automatic_enable = false,
        ensure_installed = vim.tbl_keys(servers),
      })
    end,
  },
}
