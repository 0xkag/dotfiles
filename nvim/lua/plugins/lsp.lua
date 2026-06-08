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
      "mason-org/mason-lspconfig.nvim",
      "mason-org/mason.nvim",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local completion = require("config.completion")
      local python_env = require("config.python")

      local function format_buffer(bufnr, range)
        require("conform").format({
          async = true,
          bufnr = bufnr,
          lsp_format = "fallback",
          range = range,
        })
      end

      local function code_action_menu(kind)
        return function()
          vim.lsp.buf.code_action({
            context = {
              only = { kind },
              diagnostics = vim.diagnostic.get(0),
            },
          })
        end
      end

      local function apply_code_action(kind)
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

      local function choose_type_hierarchy()
        vim.ui.select({
          { kind = "subtypes", label = "Subtypes" },
          { kind = "supertypes", label = "Supertypes" },
        }, {
          prompt = "Type hierarchy > ",
          format_item = function(item)
            return item.label
          end,
        }, function(choice)
          if not choice then
            return
          end

          vim.lsp.buf.typehierarchy(choice.kind)
        end)
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
        pylsp = {
          cmd = python_env.pylsp_cmd(),
          on_new_config = function(new_config, root_dir)
            new_config.cmd = python_env.pylsp_cmd(root_dir)
          end,
          -- pylsp advertises capabilities for every plugin even when disabled via
          -- settings. Strip the ones pyright/ruff own so other clients win rename,
          -- hover, definitions, etc. Leaves codeActionProvider (rope refactors).
          on_attach = function(client, _)
            local caps = client.server_capabilities
            caps.renameProvider = false
            caps.hoverProvider = false
            caps.completionProvider = nil
            caps.signatureHelpProvider = nil
            caps.definitionProvider = false
            caps.declarationProvider = false
            caps.typeDefinitionProvider = false
            caps.implementationProvider = false
            caps.referencesProvider = false
            caps.documentSymbolProvider = false
            caps.workspaceSymbolProvider = false
            caps.documentHighlightProvider = false
          end,
          settings = {
            pylsp = {
              plugins = {
                pyflakes = { enabled = false },
                pycodestyle = { enabled = false },
                mccabe = { enabled = false },
                pylint = { enabled = false },
                flake8 = { enabled = false },
                jedi_completion = { enabled = false },
                jedi_hover = { enabled = false },
                jedi_signature_help = { enabled = false },
                jedi_definition = { enabled = false },
                jedi_references = { enabled = false },
                jedi_symbols = { enabled = false },
                jedi_rename = { enabled = false },
                rope_rename = { enabled = false },
                pylsp_rope = { enabled = true, rename = false },
                rope_autoimport = { enabled = false },
              },
            },
          },
        },
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
        ruff = {},
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
          init_options = {
            ignoreSingleFileWarning = true,
          },
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

      local function signature_help()
        vim.lsp.buf.signature_help(completion.signature_float_opts())
      end
      local function hover()
        vim.lsp.buf.hover({ border = "rounded", close_events = { "CursorMoved", "BufHidden" } })
      end

      local function place_cursors_in_range(bufnr, ident, start_row, end_row, start_col, end_col)
        local mc = require("multicursor-nvim")
        local pat = vim.regex([[\V\<]] .. vim.fn.escape(ident, [[\]]) .. [[\>]])
        mc.action(function(ctx)
          local first = true
          local main = ctx:mainCursor()
          for lnum = start_row, end_row do
            local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
            local cstart = (lnum == start_row) and (start_col or 0) or 0
            local cend = (lnum == end_row) and (end_col or #line) or #line
            local offset = cstart
            while offset < cend do
              local ms, me = pat:match_str(line:sub(offset + 1, cend))
              if not ms then
                break
              end
              local col = offset + ms
              if first then
                main:setPos({ lnum + 1, col })
                first = false
              else
                ctx:addCursor():setPos({ lnum + 1, col })
              end
              offset = offset + me
            end
          end
        end)
      end

      local function rename_multicursor(scope)
        local ident = vim.fn.expand("<cword>")
        if ident == "" then
          vim.notify("No symbol under cursor.", vim.log.levels.INFO)
          return
        end

        local bufnr = 0
        if scope == "buffer" then
          place_cursors_in_range(bufnr, ident, 0, vim.api.nvim_buf_line_count(bufnr) - 1)
        elseif scope == "line" then
          local row = vim.api.nvim_win_get_cursor(0)[1] - 1
          place_cursors_in_range(bufnr, ident, row, row)
        elseif scope == "function" then
          local node = vim.treesitter.get_node()
          while node and node:type() ~= "function_definition" and node:type() ~= "function_declaration" do
            node = node:parent()
          end
          if not node then
            vim.notify("No enclosing function.", vim.log.levels.WARN)
            return
          end
          local srow, scol, erow, ecol = node:range()
          place_cursors_in_range(bufnr, ident, srow, erow, scol, ecol)
        end
      end

      local function pick_rename_client(bufnr)
        local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/rename" })
        if #clients == 0 then
          return nil
        end
        -- Prefer pyright over pylsp for Python; otherwise take first real provider.
        for _, c in ipairs(clients) do
          if c.name == "pyright" then
            return c
          end
        end
        return clients[1]
      end

      local function count_edits(result)
        local files, total = {}, 0
        for uri, edits in pairs(result.changes or {}) do
          table.insert(files, vim.uri_to_fname(uri))
          total = total + #edits
        end
        for _, c in ipairs(result.documentChanges or {}) do
          if c.textDocument then
            table.insert(files, vim.uri_to_fname(c.textDocument.uri))
            total = total + #(c.edits or {})
          end
        end
        return files, total
      end

      local function rename_with_preview()
        vim.ui.input({
          prompt = "New name: ",
          default = vim.fn.expand("<cword>"),
        }, function(new_name)
          if not new_name or new_name == "" then
            return
          end

          local bufnr = 0
          local client = pick_rename_client(bufnr)
          if not client then
            vim.notify("No LSP supports rename for this buffer.", vim.log.levels.WARN)
            return
          end
          local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
          params.newName = new_name

          client:request("textDocument/rename", params, function(err, result)
            if err then
              vim.notify("Rename failed: " .. err.message, vim.log.levels.ERROR)
              return
            end
            if
              not result
              or (not result.changes and not result.documentChanges)
              or (
                result.changes
                and vim.tbl_isempty(result.changes)
                and (not result.documentChanges or vim.tbl_isempty(result.documentChanges))
              )
            then
              vim.notify(
                "Rename failed: no edits returned (symbol may not be renamable here).",
                vim.log.levels.WARN
              )
              return
            end
            local files, total = count_edits(result)
            vim.ui.select({ "Apply", "Cancel" }, {
              prompt = string.format(
                "Rename to '%s': %d edits across %d files\n  %s",
                new_name,
                total,
                #files,
                table.concat(files, "\n  ")
              ),
            }, function(choice)
              if choice == "Apply" then
                vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
                vim.notify(
                  string.format("Renamed %d references in %d files.", total, #files),
                  vim.log.levels.INFO
                )
              end
            end)
          end, bufnr)
        end)
      end

      local function rename_workspace()
        if vim.g.rename_inc_preview ~= false and pcall(require, "inc_rename") then
          local cword = vim.fn.expand("<cword>")
          -- Deferred feedkeys: the ui.select float needs to close before cmdline
          -- mode takes over, otherwise the keys land in the picker.
          vim.schedule(function()
            vim.api.nvim_feedkeys(":IncRename " .. cword, "n", false)
          end)
        else
          rename_with_preview()
        end
      end

      local function rename_dispatch()
        vim.ui.select({
          "Line (multicursor)",
          "Function (multicursor)",
          "Buffer (multicursor)",
          "Workspace (LSP)",
        }, { prompt = "Rename scope:" }, function(choice)
          if not choice then
            return
          end
          if choice:find("^Workspace") then
            rename_workspace()
          elseif choice:find("^Line") then
            rename_multicursor("line")
          elseif choice:find("^Function") then
            rename_multicursor("function")
          elseif choice:find("^Buffer") then
            rename_multicursor("buffer")
          end
        end)
      end

      vim.g.rename_inc_preview = (vim.g.rename_inc_preview ~= false)

      vim.keymap.set("n", "<leader>tR", function()
        vim.g.rename_inc_preview = not vim.g.rename_inc_preview
        vim.notify(
          "inc-rename live preview " .. (vim.g.rename_inc_preview and "enabled" or "disabled"),
          vim.log.levels.INFO
        )
      end, { desc = "Toggle inc-rename live preview" })

      vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
      vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
      vim.keymap.set("n", "<leader>ex", vim.diagnostic.open_float, { desc = "Explain error" })
      vim.keymap.set("n", "<leader>en", vim.diagnostic.goto_next, { desc = "Next error" })
      vim.keymap.set("n", "<leader>ep", vim.diagnostic.goto_prev, { desc = "Previous error" })
      vim.keymap.set("n", "<leader>ec", function()
        vim.diagnostic.reset(nil, 0)
      end, { desc = "Clear errors" })

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
          map("n", "K", hover, "Hover")
          map("n", "<C-k>", signature_help, "Signature help")
          map("i", "<C-k>", signature_help, "Signature help")
          map("n", "<localleader>hs", signature_help, "Signature help")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>cr", rename_dispatch, "Rename symbol (scoped)")
          map("n", "<leader>eb", function()
            builtin.diagnostics({ bufnr = 0 })
          end, "Buffer errors")
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
          map("n", "<localleader>gd", builtin.lsp_type_definitions, "Go to type definition")
          map("n", "<localleader>gi", builtin.lsp_implementations, "Go to implementation")
          map("n", "<localleader>gr", builtin.lsp_references, "References")
          map("n", "<localleader>gR", builtin.lsp_references, "Peek references")
          map("n", "<localleader>gt", builtin.lsp_type_definitions, "Type definition")
          map("n", "<localleader>ge", function()
            builtin.diagnostics({ bufnr = bufnr })
          end, "Buffer diagnostics")
          map("n", "<localleader>gA", builtin.lsp_dynamic_workspace_symbols, "Search project type")
          map("n", "<localleader>gM", builtin.lsp_document_symbols, "Document symbols")
          map("n", "<localleader>gs", builtin.lsp_dynamic_workspace_symbols, "Workspace symbols")
          map("n", "<localleader>gS", builtin.lsp_dynamic_workspace_symbols, "All workspace symbols")
          map("n", "<localleader>gkk", choose_type_hierarchy, "Type hierarchy")
          map("n", "<localleader>gks", function()
            vim.lsp.buf.typehierarchy("subtypes")
          end, "Subtype hierarchy")
          map("n", "<localleader>gku", function()
            vim.lsp.buf.typehierarchy("supertypes")
          end, "Supertype hierarchy")
          map("n", "<localleader>gb", "<C-o>", "Jump back")
          map("n", "<localleader>gp", "<C-o>", "Jump back")
          map("n", "<localleader>gn", "<C-i>", "Jump forward")
          map("n", "<localleader>f<", vim.lsp.buf.incoming_calls, "Incoming calls")
          map("n", "<localleader>f>", vim.lsp.buf.outgoing_calls, "Outgoing calls")
          map("n", "<localleader>Fa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
          map("n", "<localleader>Fr", remove_workspace_folder, "Remove workspace folder")
          map("n", "<localleader>Fs", browse_workspace_folder, "Browse workspace folder")
          map("n", "<localleader>hh", hover, "Hover")
          map("n", "<localleader>bd", "<Cmd>checkhealth vim.lsp<CR>", "LSP session info")
          map("n", "<localleader>ea", vim.lsp.buf.code_action, "Execute code action")
          map("n", "<localleader>el", builtin.diagnostics, "List project diagnostics")
          map("n", "<localleader>br", function()
            restart_clients(bufnr)
          end, "Restart LSP")
          map("n", "<localleader>bs", function()
            shutdown_clients(bufnr)
          end, "Shutdown LSP")
          map("n", "<localleader>bv", function()
            show_client_versions(bufnr)
          end, "Client versions")
          map("n", "<localleader>qr", function()
            restart_clients(bufnr)
          end, "Restart workspace")
          map("n", "<localleader>rr", rename_dispatch, "Rename symbol (scoped)")
          map({ "n", "x" }, "<localleader>aa", vim.lsp.buf.code_action, "Code action")
          map("n", "<localleader>af", code_action_menu("quickfix"), "Fix action")
          map("n", "<localleader>ar", code_action_menu("refactor"), "Refactor action")
          map("n", "<localleader>as", code_action_menu("source"), "Source action")
          map("n", "<localleader>=b", function()
            format_buffer(bufnr)
          end, "Format buffer")
          local reflow = require("config.reflow")
          -- ,=r restyles (async) then drops the selection (vanilla gq behavior),
          -- recording the original range as the last-visual selection so gv
          -- reselects it; the async edit has not landed, so '[ '] are not valid.
          -- The stash lets ,=v restore the exact original selection afterward.
          map("x", "<localleader>=r", function()
            local range = reflow.selection_range()
            reflow.stash_visual()
            reflow.restyle(range)
            vim.cmd(string.format("normal! %dGV%dG\27", range.start[1], range["end"][1]))
          end, "Format selection (restyle)")
          -- ,=q always restyles; in visual mode stash the original, drop the
          -- selection afterward, and record the operated extent ('[ '] for a sync
          -- reflow fallback, else the original range) so gv reselects it.
          map({ "n", "x" }, "<localleader>=q", function()
            if vim.fn.mode():match("[vV\22]") then
              local range = reflow.selection_range()
              reflow.stash_visual()
              local reflowed = reflow.dispatch_range(range, true)
              if reflowed then
                vim.cmd("normal! `[V`]\27")
              else
                vim.cmd(string.format("normal! %dGV%dG\27", range.start[1], range["end"][1]))
              end
            else
              reflow._pending_restyle = true
              vim.o.operatorfunc = "v:lua.require'config.reflow'.opfunc"
              vim.api.nvim_feedkeys("g@", "n", false)
            end
          end, "Restyle (formatter)")
          map("n", "<localleader>=t", reflow.cycle, "Cycle reflow mode")
          map("n", "<localleader>=v", reflow.reselect_visual, "Reselect original visual")
          map("n", "<localleader>=o", apply_code_action("source.organizeImports"), "Organize imports")
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

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.server_capabilities.signatureHelpProvider and not vim.b[bufnr].lsp_signature_autocmd then
            vim.b[bufnr].lsp_signature_autocmd = true
            vim.api.nvim_create_autocmd("InsertCharPre", {
              buffer = bufnr,
              callback = function()
                if completion.signature_auto_enabled() and vim.v.char == "(" then
                  vim.schedule(function()
                    if vim.api.nvim_get_current_buf() == bufnr then
                      signature_help()
                    end
                  end)
                end
              end,
            })

            local function clean_label(raw)
              local name, default = raw:match("^%s*([^:=]-)%s*:.-=%s*(.*)$")
              if name and name ~= "" then
                return name .. "=" .. default
              end
              name, default = raw:match("^%s*([^:=]-)%s*=%s*(.*)$")
              if name and name ~= "" then
                return name .. "=" .. default
              end
              local no_type = raw:match("^%s*([^:]+)%s*:")
              if no_type then
                return vim.trim(no_type)
              end
              return vim.trim(raw)
            end

            local function bare_name(raw)
              local stripped = raw:match("^%s*%*?%*?([%w_]+)")
              return stripped or vim.trim(raw)
            end

            local function is_kwargable(raw)
              local trimmed = vim.trim(raw)
              return trimmed ~= "*" and trimmed ~= "/" and not trimmed:match("^%*")
            end

            local function prepare_for_expand()
              -- Ensures there is a ( immediately before cursor and ) immediately after,
              -- so signatureHelp returns real data and lsp_expand inserts between them.
              -- Returns the row/col where expansion should happen plus rollback state.
              local line = vim.api.nvim_get_current_line()
              local row, col = unpack(vim.api.nvim_win_get_cursor(0))
              local before = line:sub(1, col)
              local after = line:sub(col + 1)

              if before:match("%($") and after:match("^%s*%)") then
                return { row = row, col = col }
              elseif before:match("%($") then
                vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { ")" })
                return {
                  row = row,
                  col = col,
                  inserted = { row = row - 1, start_col = col, end_col = col + 1, text = ")" },
                }
              else
                local word_end = col
                while word_end < #line and line:sub(word_end + 1, word_end + 1):match("[%w_]") do
                  word_end = word_end + 1
                end
                vim.api.nvim_buf_set_text(0, row - 1, word_end, row - 1, word_end, { "()" })
                vim.api.nvim_win_set_cursor(0, { row, word_end + 1 })
                return {
                  row = row,
                  col = word_end + 1,
                  inserted = { row = row - 1, start_col = word_end, end_col = word_end + 2, text = "()" },
                }
              end
            end

            local function rollback_expand(ctx)
              if not ctx.inserted or not vim.api.nvim_buf_is_valid(bufnr) then
                return
              end

              local inserted = ctx.inserted
              local line = vim.api.nvim_buf_get_lines(bufnr, inserted.row, inserted.row + 1, false)[1]
              if not line then
                return
              end

              local current = line:sub(inserted.start_col + 1, inserted.end_col)
              if current == inserted.text then
                vim.api.nvim_buf_set_text(bufnr, inserted.row, inserted.start_col, inserted.row, inserted.end_col, { "" })
              end
            end

            local function fetch_signature(callback, on_fail)
              local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
              vim.lsp.buf_request(bufnr, "textDocument/signatureHelp", params, function(err, result)
                if err or not result or not result.signatures or #result.signatures == 0 then
                  vim.notify("No signature help available.", vim.log.levels.INFO)
                  if on_fail then
                    on_fail()
                  end
                  return
                end
                if #result.signatures == 1 then
                  callback(result.signatures[1])
                  return
                end
                vim.schedule(function()
                  vim.ui.select(result.signatures, {
                    prompt = "Signature:",
                    format_item = function(s)
                      return s.label
                    end,
                  }, function(choice)
                    if choice then
                      callback(choice)
                    elseif on_fail then
                      on_fail()
                    end
                  end)
                end)
              end)
            end

            local function param_label(sig, param)
              if type(param.label) == "table" then
                return sig.label:sub(param.label[1] + 1, param.label[2])
              end
              return param.label
            end

            local function do_expand(parts, row, col)
              vim.api.nvim_win_set_cursor(0, { row, col })
              require("luasnip").lsp_expand(table.concat(parts, ", "))
            end

            local function expand_call_template()
              local ctx = prepare_for_expand()
              fetch_signature(function(sig)
                local parts = {}
                for i, p in ipairs(sig.parameters or {}) do
                  local label = param_label(sig, p)
                  table.insert(parts, string.format("${%d:%s}", i, clean_label(label)))
                end
                if #parts == 0 then
                  rollback_expand(ctx)
                  vim.notify("No parameters.", vim.log.levels.INFO)
                  return
                end
                vim.schedule(function()
                  do_expand(parts, ctx.row, ctx.col)
                end)
              end, function()
                rollback_expand(ctx)
              end)
            end

            local function expand_kwargs_template()
              local ctx = prepare_for_expand()
              fetch_signature(function(sig)
                local parts = {}
                local idx = 1
                for _, p in ipairs(sig.parameters or {}) do
                  local label = param_label(sig, p)
                  if is_kwargable(label) then
                    local name = bare_name(label)
                    table.insert(parts, string.format("%s=${%d:%s}", name, idx, name))
                    idx = idx + 1
                  end
                end
                if #parts == 0 then
                  rollback_expand(ctx)
                  vim.notify("No keyword-passable parameters.", vim.log.levels.INFO)
                  return
                end
                vim.schedule(function()
                  do_expand(parts, ctx.row, ctx.col)
                end)
              end, function()
                rollback_expand(ctx)
              end)
            end

            map("n", "<localleader>ia", expand_call_template, "Insert call arguments")
            map("n", "<localleader>ik", expand_kwargs_template, "Insert call kwargs")
          end
        end,
      })

      for name, config in pairs(servers) do
        config.capabilities = vim.tbl_deep_extend("force", {}, capabilities, config.capabilities or {})
        vim.lsp.config(name, config)
        vim.lsp.enable(name)
      end

      vim.api.nvim_create_user_command("PyrightWorkspaceMode", function()
        local clients = vim.lsp.get_clients({ name = "pyright" })
        if #clients == 0 then
          vim.notify("No active pyright client.", vim.log.levels.WARN)
          return
        end

        for _, client in ipairs(clients) do
          client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
            python = { analysis = { diagnosticMode = "workspace" } },
          })
          client:notify("workspace/didChangeConfiguration", { settings = client.settings })
        end

        vim.notify("Pyright: workspace diagnostics enabled for this session.", vim.log.levels.INFO)
      end, { desc = "Enable pyright workspace-wide diagnostics for this session" })

      require("mason-lspconfig").setup({
        automatic_enable = false,
      })
    end,
  },
}
