-- Headless test for config.lsp_signature: the signature-help float, the
-- auto-popup on "(", and the call-template expansion behind ,ia and ,ik.
-- Run: nvim/test/run.sh lsp_signature
--
-- prepare_for_expand makes sure the cursor sits between "(" and ")" before
-- signatureHelp is asked, inserting what is missing and remembering it so
-- rollback_expand can take it out again when the server has nothing to say.
-- Both were closures inside the LspAttach handler until the lsp.lua split.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/lsp_signature_spec.lua$", "")
package.path = here .. "/lua/?.lua;" .. here .. "/lua/?/init.lua;" .. package.path

local failures = {}
local function check(name, cond, detail)
  if cond then
    io.write("ok   - " .. name .. "\n")
  else
    io.write("FAIL - " .. name .. " :: " .. tostring(detail) .. "\n")
    table.insert(failures, name)
  end
end

vim.notify = function() end

local ok, signature = pcall(require, "config.lsp_signature")
check("config.lsp_signature loads", ok, signature)
if not ok then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
end

local function set_line(line, col)
  vim.cmd("enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, col })
  return vim.api.nvim_get_current_buf()
end
local function line()
  return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
end

-- Already between parens: nothing to insert, nothing to roll back.
do
  local buf = set_line("call()", 5)
  local ctx = signature.prepare_for_expand()
  check("between parens leaves the line alone", line() == "call()", line())
  check("and reports the cursor", ctx.row == 1 and ctx.col == 5 and ctx.inserted == nil, vim.inspect(ctx))
  signature.rollback_expand(ctx, buf)
  check("rollback with nothing inserted is a no-op", line() == "call()", line())
end

-- On a bare name: "()" goes after the word and the cursor moves inside.
do
  local buf = set_line("call", 0)
  local ctx = signature.prepare_for_expand()
  check("a bare name gains parens", line() == "call()", line())
  check("the cursor sits between them", ctx.col == 5 and vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 5 }), vim.inspect({ ctx, vim.api.nvim_win_get_cursor(0) }))
  check("the insertion is remembered", ctx.inserted and ctx.inserted.text == "()" and ctx.inserted.start_col == 4 and ctx.inserted.end_col == 6, vim.inspect(ctx.inserted))
  signature.rollback_expand(ctx, buf)
  check("rollback removes exactly the parens", line() == "call", line())
end

-- After an open paren with no close: ")" is added, and rollback leaves user
-- edits alone.
do
  local buf = set_line("call(x", 5)
  local ctx = signature.prepare_for_expand()
  check("an open paren gains its close", line() == "call()x", line())
  check("only the close is remembered", ctx.inserted and ctx.inserted.text == ")" and ctx.inserted.start_col == 5, vim.inspect(ctx.inserted))
  vim.api.nvim_buf_set_text(0, 0, 5, 0, 6, { "]" })
  signature.rollback_expand(ctx, buf)
  check("rollback keeps text the user changed", line() == "call(]x", line())
end

-- attach(): once per buffer, only for a client that offers signature help;
-- it installs the "(" auto-popup and the two template keys.
do
  local buf = set_line("", 0)
  local plain = { server_capabilities = {} }
  check("a client without signature help attaches nothing", signature.attach(buf, plain) == false and vim.fn.maparg("<localleader>ia", "n") == "", vim.fn.maparg("<localleader>ia", "n"))

  local client = { server_capabilities = { signatureHelpProvider = {} }, offset_encoding = "utf-16" }
  check("a client with signature help attaches", signature.attach(buf, client) == true)
  local popup = vim.api.nvim_get_autocmds({ buffer = buf, event = "InsertCharPre" })
  check("the auto-popup autocmd is installed", #popup == 1, #popup)
  check(",ia is mapped in the buffer", vim.fn.maparg("<localleader>ia", "n", false, true).buffer == 1, vim.inspect(vim.fn.maparg("<localleader>ia", "n", false, true)))
  check(",ik is mapped in the buffer", vim.fn.maparg("<localleader>ik", "n", false, true).buffer == 1)
  check("a second attach is a no-op", signature.attach(buf, client) == false and #vim.api.nvim_get_autocmds({ buffer = buf, event = "InsertCharPre" }) == 1)
end

check("show() is the signature float", type(signature.show) == "function")

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
