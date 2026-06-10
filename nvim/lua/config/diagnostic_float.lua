-- Auto-show the diagnostic under the cursor in a float on CursorHold, since
-- virtual_text is disabled (see vim.diagnostic.config in lua/plugins/lsp.lua).
-- The float is non-focusable and scoped to the cursor, so it only appears when
-- a diagnostic is actually under the cursor and never steals focus. Toggle it
-- with <leader>td (see lua/config/keymaps.lua).
local M = {}

local enabled = true
local did_setup = false

local function show_float()
  if not enabled then
    return
  end
  -- Do not stack a float on top of an existing floating window.
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  vim.diagnostic.open_float(nil, {
    scope = "cursor",
    focusable = false,
    border = "rounded",
    close_events = { "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" },
  })
end

function M.setup()
  if did_setup then
    return
  end
  did_setup = true

  local group = vim.api.nvim_create_augroup("diagnostic_float", { clear = true })
  vim.api.nvim_create_autocmd("CursorHold", {
    group = group,
    callback = show_float,
  })
end

function M.toggle()
  enabled = not enabled
  vim.notify(
    "Diagnostic hover float " .. (enabled and "enabled" or "disabled"),
    vim.log.levels.INFO
  )
end

function M.is_enabled()
  return enabled
end

return M
