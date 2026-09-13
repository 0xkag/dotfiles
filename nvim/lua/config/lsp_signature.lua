-- Signature help: the float behind <C-k> and ,hs, the auto-popup on "(" when
-- enabled (<leader>th), and the call-template expansion behind ,ia and ,ik,
-- which asks the server for the signature under the cursor and inserts a
-- snippet with one placeholder per parameter (or per keyword-passable one).
local M = {}

local completion = require("config.completion")
local lsp_util = require("config.lsp_util")
local shared = require("config.code_mode.shared")

function M.show()
  vim.lsp.buf.signature_help(completion.signature_float_opts())
end

-- Ensures there is a ( immediately before the cursor and ) immediately after,
-- so signatureHelp returns real data and lsp_expand inserts between them.
-- Returns the row/col where expansion should happen plus what was inserted,
-- for rollback_expand.
function M.prepare_for_expand()
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

-- Takes out what prepare_for_expand inserted, if it is still there unchanged.
function M.rollback_expand(ctx, bufnr)
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

local function fetch_signature(bufnr, client, callback, on_fail)
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

local function do_expand(parts, row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
  require("luasnip").lsp_expand(table.concat(parts, ", "))
end

-- One placeholder per parameter, in order.
function M.expand_call(bufnr, client)
  local ctx = M.prepare_for_expand()
  fetch_signature(bufnr, client, function(sig)
    local parts = {}
    for i, p in ipairs(sig.parameters or {}) do
      local label = lsp_util.param_label(sig, p)
      table.insert(parts, string.format("${%d:%s}", i, lsp_util.clean_label(label)))
    end
    if #parts == 0 then
      M.rollback_expand(ctx, bufnr)
      vim.notify("No parameters.", vim.log.levels.INFO)
      return
    end
    vim.schedule(function()
      do_expand(parts, ctx.row, ctx.col)
    end)
  end, function()
    M.rollback_expand(ctx, bufnr)
  end)
end

-- name=placeholder for every keyword-passable parameter.
function M.expand_kwargs(bufnr, client)
  local ctx = M.prepare_for_expand()
  fetch_signature(bufnr, client, function(sig)
    local parts = {}
    local idx = 1
    for _, p in ipairs(sig.parameters or {}) do
      local label = lsp_util.param_label(sig, p)
      if lsp_util.is_kwargable(label) then
        local name = lsp_util.bare_name(label)
        table.insert(parts, string.format("%s=${%d:%s}", name, idx, name))
        idx = idx + 1
      end
    end
    if #parts == 0 then
      M.rollback_expand(ctx, bufnr)
      vim.notify("No keyword-passable parameters.", vim.log.levels.INFO)
      return
    end
    vim.schedule(function()
      do_expand(parts, ctx.row, ctx.col)
    end)
  end, function()
    M.rollback_expand(ctx, bufnr)
  end)
end

-- Once per buffer, for a client that offers signature help: the "(" auto-popup
-- and the template keys. Returns whether anything was installed.
function M.attach(bufnr, client)
  if not client or not client.server_capabilities.signatureHelpProvider or vim.b[bufnr].lsp_signature_autocmd then
    return false
  end
  vim.b[bufnr].lsp_signature_autocmd = true

  vim.api.nvim_create_autocmd("InsertCharPre", {
    buffer = bufnr,
    callback = function()
      if completion.signature_auto_enabled() and vim.v.char == "(" then
        vim.schedule(function()
          if vim.api.nvim_get_current_buf() == bufnr then
            M.show()
          end
        end)
      end
    end,
  })

  local map = shared.buf_map(bufnr)
  map("n", "<localleader>ia", function()
    M.expand_call(bufnr, client)
  end, "Insert call arguments")
  map("n", "<localleader>ik", function()
    M.expand_kwargs(bufnr, client)
  end, "Insert call kwargs")
  return true
end

return M
