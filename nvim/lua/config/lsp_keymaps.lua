-- The LSP keys: the global diagnostic and rename-preview keys from setup(),
-- and the per-buffer set attach() installs on every LspAttach: the g-prefix
-- navigation, the <leader>c code group, and the Spacemacs major-mode
-- localleader parity (goto, backend, action, format, execute, workspace). The
-- rename menu is config.lsp_rename; signature help and the call templates are
-- config.lsp_signature.
local M = {}

local lsp_rename = require("config.lsp_rename")
local lsp_signature = require("config.lsp_signature")
local lsp_util = require("config.lsp_util")
local shared = require("config.code_mode.shared")

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

local function ensure_clients(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    vim.notify("No active LSP client for this buffer.", vim.log.levels.INFO)
    return nil
  end

  return clients
end

local function restart_clients(bufnr)
  local clients = ensure_clients(bufnr)
  if not clients then
    return
  end

  lsp_util.stop_clients(clients)
  vim.schedule(function()
    vim.cmd.edit()
  end)
end

local function shutdown_clients(bufnr)
  local clients = ensure_clients(bufnr)
  if not clients then
    return
  end

  lsp_util.stop_clients(clients)
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
  local clients = ensure_clients(bufnr)
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
  if not ensure_clients(bufnr) then
    return
  end

  vim.lsp.buf.document_highlight()
end

local function refresh_codelens(bufnr)
  vim.lsp.codelens.refresh({ bufnr = bufnr })
end

local function run_codelens(bufnr)
  vim.lsp.codelens.refresh({ bufnr = bufnr })
  vim.lsp.codelens.run()
end

local function toggle_inlay_hints(bufnr)
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
end

-- The default K hover restated with a border and its own close events.
local function hover()
  vim.lsp.buf.hover({ border = "rounded", close_events = { "CursorMoved", "BufHidden" } })
end

-- `[d` / `]d` are Neovim's own since 0.11, with this same jump call, so they
-- are not repeated; these back the leader-key spellings.
local function diagnostic_jump(count)
  return function()
    vim.diagnostic.jump({ count = count })
  end
end

-- The buffer's keys, installed on LspAttach. `client` may be nil when the
-- client has gone away between the event and the handler.
function M.attach(bufnr, client)
  local builtin = require("telescope.builtin")
  local map = shared.buf_map(bufnr)

  map("n", "gd", function()
    builtin.lsp_definitions({ reuse_win = true })
  end, "Go to definition")
  map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
  map("n", "gi", builtin.lsp_implementations, "Go to implementation")
  map("n", "gr", builtin.lsp_references, "References")
  map("n", "gy", builtin.lsp_type_definitions, "Type definitions")
  map("n", "K", hover, "Hover")
  map("n", "<C-k>", lsp_signature.show, "Signature help")
  map("i", "<C-k>", lsp_signature.show, "Signature help")
  map("n", "<localleader>hs", lsp_signature.show, "Signature help")
  map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("n", "<leader>cr", lsp_rename.dispatch, "Rename symbol (scoped)")
  map("n", "<leader>eb", function()
    builtin.diagnostics({ bufnr = 0 })
  end, "Buffer errors")
  map("n", "<leader>cs", builtin.lsp_document_symbols, "Document symbols")
  map("n", "<leader>cS", builtin.lsp_dynamic_workspace_symbols, "Workspace symbols")
  map("n", "<leader>ci", builtin.lsp_implementations, "Implementations")
  map("n", "<leader>cR", builtin.lsp_references, "References")
  map("n", "<leader>cy", builtin.lsp_type_definitions, "Type definitions")
  map("n", "<leader>ch", function()
    toggle_inlay_hints(bufnr)
  end, "Toggle inlay hints")

  -- Spacemacs major-mode localleader parity for code navigation.
  map("n", "<localleader>gg", function()
    builtin.lsp_definitions({ reuse_win = true })
  end, "Go to definition")
  map("n", "<localleader>gD", vim.lsp.buf.declaration, "Go to declaration")
  map("n", "<localleader>gd", builtin.lsp_type_definitions, "Go to type definition")
  map("n", "<localleader>gi", builtin.lsp_implementations, "Go to implementation")
  map("n", "<localleader>gr", builtin.lsp_references, "References")
  map("n", "<localleader>ge", function()
    builtin.diagnostics({ bufnr = bufnr })
  end, "Buffer diagnostics")
  map("n", "<localleader>gM", builtin.lsp_document_symbols, "Document symbols")
  map("n", "<localleader>gs", builtin.lsp_dynamic_workspace_symbols, "Workspace symbols")
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
  map("n", "<localleader>rr", lsp_rename.dispatch, "Rename symbol (scoped)")
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
  map("n", "<localleader>Tl", function()
    toggle_inlay_hints(bufnr)
  end, "Toggle inlay hints")

  lsp_signature.attach(bufnr, client)
end

-- The global keys and the LspAttach handler.
function M.setup()
  vim.keymap.set("n", "<leader>tR", lsp_rename.toggle_preview, { desc = "Toggle inc-rename live preview" })
  vim.keymap.set("n", "<leader>ex", vim.diagnostic.open_float, { desc = "Explain error" })
  vim.keymap.set("n", "<leader>en", diagnostic_jump(1), { desc = "Next error" })
  vim.keymap.set("n", "<leader>ep", diagnostic_jump(-1), { desc = "Previous error" })
  vim.keymap.set("n", "<leader>ec", function()
    vim.diagnostic.reset(nil, 0)
  end, { desc = "Clear errors" })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("user_lsp_keymaps", { clear = true }),
    callback = function(event)
      M.attach(event.buf, vim.lsp.get_client_by_id(event.data.client_id))
    end,
  })
end

return M
