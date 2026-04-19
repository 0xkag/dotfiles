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

      local function format_buffer(bufnr, range)
        require("conform").format({
          async = true,
          bufnr = bufnr,
          lsp_format = "fallback",
          range = range,
        })
      end

      local function code_action_only(kind)
        return function()
          vim.lsp.buf.code_action({
            apply = true,
            context = {
              only = { kind },
              diagnostics = vim.diagnostic.get(0),
            },
          })
        end
      end

      local function clients_for(bufnr)
        return vim.lsp.get_clients({ bufnr = bufnr })
      end

      local function ensure_clients(bufnr, action)
        local clients = clients_for(bufnr)
        if #clients == 0 then
          vim.notify("No active LSP client for this buffer.", vim.log.levels.INFO)
          return nil
        end

        return clients
      end

      local function restart_clients(bufnr)
        local clients = ensure_clients(bufnr, "restart")
        if not clients then
          return
        end

        vim.lsp.stop_client(vim.tbl_map(function(client)
          return client.id
        end, clients), true)
        vim.schedule(function()
          vim.cmd.edit()
        end)
      end

      local function shutdown_clients(bufnr)
        local clients = ensure_clients(bufnr, "shutdown")
        if not clients then
          return
        end

        vim.lsp.stop_client(vim.tbl_map(function(client)
          return client.id
        end, clients), true)
      end

      local function select_workspace_folder(prompt, callback)
        local folders = vim.lsp.buf.list_workspace_folders()
        if #folders == 0 then
          vim.notify("No workspace folders are registered for this buffer.", vim.log.levels.INFO)
          return
        end

        vim.ui.select(folders, {
          prompt = prompt,
        }, callback)
      end

      local function browse_workspace_folder()
        local builtin = require("telescope.builtin")
        select_workspace_folder("Workspace folder > ", function(folder)
          if not folder then
            return
          end

          builtin.find_files({ cwd = folder })
        end)
      end

      local function remove_workspace_folder()
        select_workspace_folder("Remove workspace folder > ", function(folder)
          if folder then
            vim.lsp.buf.remove_workspace_folder(folder)
          end
        end)
      end

      local function show_client_versions(bufnr)
        local clients = ensure_clients(bufnr, "inspect")
        if not clients then
          return
        end

        local lines = {}
        for _, client in ipairs(clients) do
          local line = client.name
          local version = client.server_info and client.server_info.version or nil
          if version and version ~= "" then
            line = line .. " " .. version
          end

          local cmd = type(client.config.cmd) == "table" and client.config.cmd[1] or client.config.cmd
          if cmd and cmd ~= "" then
            line = line .. " [" .. cmd .. "]"
          end

          table.insert(lines, line)
        end

        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, {
          title = "Active LSP clients",
        })
      end

      local function highlight_symbol(bufnr)
        if not ensure_clients(bufnr, "highlight") then
          return
        end

        vim.lsp.buf.document_highlight()
      end

      local function refresh_codelens(bufnr)
        if not vim.lsp.codelens then
          vim.notify("Code lenses are not available in this Neovim build.", vim.log.levels.INFO)
          return
        end

        vim.lsp.codelens.refresh({ bufnr = bufnr })
      end

      local function run_codelens(bufnr)
        if not vim.lsp.codelens then
          vim.notify("Code lenses are not available in this Neovim build.", vim.log.levels.INFO)
          return
        end

        vim.lsp.codelens.refresh({ bufnr = bufnr })
        vim.lsp.codelens.run()
      end

      local function toggle_inlay_hints(bufnr)
        if not vim.lsp.inlay_hint then
          vim.notify("Inlay hints are not available in this Neovim build.", vim.log.levels.INFO)
          return
        end

        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
      end

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
          map("n", "<localleader>ge", function()
            builtin.diagnostics({ bufnr = bufnr })
          end, "Buffer diagnostics")
          map("n", "<localleader>gM", builtin.lsp_document_symbols, "Document symbols")
          map("n", "<localleader>gs", builtin.lsp_dynamic_workspace_symbols, "Workspace symbols")
          map("n", "<localleader>gS", builtin.lsp_dynamic_workspace_symbols, "All workspace symbols")
          map("n", "<localleader>gb", "<C-o>", "Jump back")
          map("n", "<localleader>gp", "<C-o>", "Jump back")
          map("n", "<localleader>gn", "<C-i>", "Jump forward")
          map("n", "<localleader>Fa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
          map("n", "<localleader>Fr", remove_workspace_folder, "Remove workspace folder")
          map("n", "<localleader>Fs", browse_workspace_folder, "Browse workspace folder")
          map("n", "<localleader>hh", vim.lsp.buf.hover, "Hover")
          map("n", "<localleader>bd", "<Cmd>checkhealth vim.lsp<CR>", "LSP session info")
          map("n", "<localleader>br", function()
            restart_clients(bufnr)
          end, "Restart LSP")
          map("n", "<localleader>bs", function()
            shutdown_clients(bufnr)
          end, "Shutdown LSP")
          map("n", "<localleader>bv", function()
            show_client_versions(bufnr)
          end, "Client versions")
          map("n", "<localleader>rr", vim.lsp.buf.rename, "Rename symbol")
          map({ "n", "x" }, "<localleader>aa", vim.lsp.buf.code_action, "Code action")
          map("n", "<localleader>af", code_action_only("quickfix"), "Fix action")
          map("n", "<localleader>ar", code_action_only("refactor"), "Refactor action")
          map("n", "<localleader>as", code_action_only("source"), "Source action")
          map("n", "<localleader>=b", function()
            format_buffer(bufnr)
          end, "Format buffer")
          map("x", "<localleader>=r", function()
            local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
            local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
            format_buffer(bufnr, {
              start = { start_pos[1], start_pos[2] },
              ["end"] = { end_pos[1], end_pos[2] + 1 },
            })
          end, "Format selection")
          map("n", "<localleader>=o", code_action_only("source.organizeImports"), "Organize imports")
          map("n", "<localleader>xh", function()
            highlight_symbol(bufnr)
          end, "Highlight symbol references")
          map("n", "<localleader>xl", function()
            refresh_codelens(bufnr)
          end, "Refresh code lenses")
          map("n", "<localleader>xL", function()
            run_codelens(bufnr)
          end, "Run code lens")

          if vim.lsp.inlay_hint then
            map("n", "<leader>ch", function()
              toggle_inlay_hints(bufnr)
            end, "Toggle inlay hints")
            map("n", "<localleader>Tl", function()
              toggle_inlay_hints(bufnr)
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
