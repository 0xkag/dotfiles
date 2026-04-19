-- ~/.config/nvim/lua/plugins/lsp.lua

return {
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
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "mason-org/mason-lspconfig.nvim",
      "mason-org/mason.nvim",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local python_env = require("config.python")
      local function refresh_pyright_config(new_config, root_dir)
        new_config.settings = vim.tbl_deep_extend(
          "force",
          new_config.settings or {},
          python_env.pyright_settings(root_dir)
        )
      end

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
          before_init = function(_, new_config)
            refresh_pyright_config(new_config, new_config.root_dir)
          end,
          on_attach = function(client, bufnr)
            vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightSetPythonPath", function(command)
              local path = command.args
              client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
                python = { pythonPath = path },
              })
              client:notify("workspace/didChangeConfiguration", {
                settings = client.settings,
              })
            end, {
              complete = "file",
              desc = "Reconfigure pyright with the provided python path",
              nargs = 1,
            })
          end,
          on_new_config = function(new_config, root_dir)
            refresh_pyright_config(new_config, root_dir)
          end,
          settings = python_env.pyright_settings(),
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
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, {
              buffer = bufnr,
              desc = desc,
              silent = true,
            })
          end

          map("n", "gd", function()
            builtin.lsp_definitions({ reuse_win = true })
          end, "Go to definition")
          map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
          map("n", "gi", builtin.lsp_implementations, "Go to implementation")
          map("n", "gr", builtin.lsp_references, "References")
          map("n", "gy", builtin.lsp_type_definitions, "Type definitions")
          map("n", "K", vim.lsp.buf.hover, "Hover")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map("n", "<leader>cd", function()
            builtin.diagnostics({ bufnr = 0 })
          end, "Buffer diagnostics")
          map("n", "<leader>cs", builtin.lsp_document_symbols, "Document symbols")
          map("n", "<leader>cS", builtin.lsp_dynamic_workspace_symbols, "Workspace symbols")
          map("n", "<leader>ci", builtin.lsp_implementations, "Implementations")
          map("n", "<leader>cR", builtin.lsp_references, "References")
          map("n", "<leader>cy", builtin.lsp_type_definitions, "Type definitions")

          -- Spacemacs major-mode localleader parity for code navigation.
          map("n", "<localleader>gg", function()
            builtin.lsp_definitions({ reuse_win = true })
          end, "Go to definition")
          map("n", "<localleader>gD", vim.lsp.buf.declaration, "Go to declaration")
          map("n", "<localleader>gi", builtin.lsp_implementations, "Go to implementation")
          map("n", "<localleader>gr", builtin.lsp_references, "References")
          map("n", "<localleader>gt", builtin.lsp_type_definitions, "Type definition")
          map("n", "<localleader>gs", builtin.lsp_dynamic_workspace_symbols, "Workspace symbols")
          map("n", "<localleader>gb", "<C-o>", "Jump back")
          map("n", "<localleader>hh", vim.lsp.buf.hover, "Hover")
          map("n", "<localleader>rr", vim.lsp.buf.rename, "Rename symbol")
          map({ "n", "x" }, "<localleader>aa", vim.lsp.buf.code_action, "Code action")
          map("n", "<localleader>=b", function()
            require("conform").format({
              async = true,
              lsp_format = "fallback",
            })
          end, "Format buffer")

          if vim.lsp.inlay_hint then
            map("n", "<leader>ch", function()
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
      })
    end,
  },
}
