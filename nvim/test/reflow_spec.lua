-- Headless test harness for config.reflow.
-- Run: nvim --headless -u NONE -l nvim/test/reflow_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/reflow_spec.lua$", "")
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

local reflow = require("config.reflow")

-- Mode cycle: builtin -> lsp -> smart -> conservative -> builtin
check("default mode is builtin", reflow.mode == "builtin", reflow.mode)
reflow.cycle()
check("cycle 1 -> lsp", reflow.mode == "lsp", reflow.mode)
reflow.cycle()
check("cycle 2 -> smart", reflow.mode == "smart", reflow.mode)
reflow.cycle()
check("cycle 3 -> conservative", reflow.mode == "conservative", reflow.mode)
reflow.cycle()
check("cycle 4 -> builtin", reflow.mode == "builtin", reflow.mode)

-- selection_range() must read the LIVE visual selection (getpos v/.),
-- not the stale '< '> marks, and return 1-indexed {line,col} bounds.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE" })
local captured
vim.keymap.set("x", "<Plug>(reflow_test_cap)", function()
  captured = reflow.selection_range()
end)
-- Select lines 2..4 (1-indexed) then invoke the mapping from visual mode.
vim.api.nvim_feedkeys(
  vim.api.nvim_replace_termcodes("2GVjj", true, false, true), "x", false)
vim.api.nvim_feedkeys(
  vim.api.nvim_replace_termcodes("\\<Plug>(reflow_test_cap)", true, true, true), "xt", false)
check("selection_range start line", captured and captured.start[1] == 2, captured and captured.start[1])
check("selection_range end line", captured and captured["end"][1] == 4, captured and captured["end"][1])
check("selection_range start col 0-indexed", captured and captured.start[2] == 0, captured and captured.start[2])
check("selection_range end col 0-indexed", captured and captured["end"][2] == 0, captured and captured["end"][2])

-- reflow_builtin wraps the operated range at textwidth and preserves a
-- comment leader on each wrapped line.
-- The selection_range test above leaves us in visual mode; drop to normal so
-- the `normal! `[V`]gq` below operates cleanly. Under `-u NONE` no lua
-- ftplugin runs, so set 'comments' to the `--` leader it would normally add.
vim.api.nvim_feedkeys(
  vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
vim.bo.textwidth = 40
vim.bo.filetype = "lua"
vim.bo.comments = ":--"
vim.bo.formatoptions = "tcqj"
vim.bo.indentexpr = ""
vim.bo.formatexpr = ""
local long = "-- " .. string.rep("word ", 20)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { long })
-- Set the change marks '[ '] to cover line 1, as an operator would.
vim.api.nvim_buf_set_mark(0, "[", 1, 0, {})
vim.api.nvim_buf_set_mark(0, "]", 1, #long - 1, {})
reflow.reflow_builtin()
local out = vim.api.nvim_buf_get_lines(0, 0, -1, false)
check("reflow_builtin wraps to multiple lines", #out > 1, #out)
check("reflow_builtin keeps comment leader", out[2]:match("^%-%-") ~= nil, out[2])
check("reflow_builtin respects textwidth", #out[1] <= 40, #out[1])

-- restyle(range) must call conform.format with lsp_format=fallback and the
-- given range; conservative mode for python must request the autopep8 formatter.
local last_call
package.loaded["conform"] = {
  format = function(opts) last_call = opts end,
  get_formatter_info = function() return { available = true } end,
}
local rng = { start = { 2, 0 }, ["end"] = { 4, 1 } }
reflow.mode = "lsp"
vim.bo.filetype = "python"
reflow.restyle(rng)
check("restyle passes range", last_call and last_call.range == rng, last_call and last_call.range)
check("restyle uses lsp fallback", last_call and last_call.lsp_format == "fallback", last_call and last_call.lsp_format)

reflow.mode = "conservative"
reflow.restyle(rng)
check("conservative targets autopep8",
  last_call and last_call.formatters and last_call.formatters[1] == "autopep8",
  last_call and last_call.formatters)
reflow.mode = "builtin"

-- dispatch_range routing: builtin -> reflow; force_restyle -> restyle;
-- smart on a comment node -> reflow.
local routed
reflow._reflow_builtin_real = reflow.reflow_builtin
reflow._restyle_real = reflow.restyle
reflow.reflow_builtin = function() routed = "reflow" end
reflow.restyle = function() routed = "restyle" end

reflow.mode = "builtin"
routed = nil
reflow.dispatch_range({ start = { 1, 0 }, ["end"] = { 1, 1 } }, false)
check("builtin routes to reflow", routed == "reflow", routed)

routed = nil
reflow.dispatch_range({ start = { 1, 0 }, ["end"] = { 1, 1 } }, true)
check("force_restyle routes to restyle", routed == "restyle", routed)

reflow.mode = "lsp"
routed = nil
reflow.dispatch_range({ start = { 1, 0 }, ["end"] = { 1, 1 } }, false)
check("lsp mode routes to restyle", routed == "restyle", routed)

reflow.reflow_builtin = reflow._reflow_builtin_real
reflow.restyle = reflow._restyle_real
reflow.mode = "builtin"

-- smart mode: treesitter routes comment/string -> reflow, code -> restyle.
-- Uses the bundled lua parser (works under -u NONE).
local routed2
reflow._rb = reflow.reflow_builtin
reflow._rs = reflow.restyle
reflow.reflow_builtin = function() routed2 = "reflow" end
reflow.restyle = function() routed2 = "restyle" end
reflow.mode = "smart"

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "-- a comment line here", "local x = 1" })
vim.bo.filetype = "lua"

routed2 = nil
reflow.dispatch_range({ start = { 1, 4 }, ["end"] = { 1, 10 } }, false)
check("smart routes comment to reflow", routed2 == "reflow", routed2)

routed2 = nil
reflow.dispatch_range({ start = { 2, 6 }, ["end"] = { 2, 10 } }, false)
check("smart routes code to restyle", routed2 == "restyle", routed2)

reflow.reflow_builtin = reflow._rb
reflow.restyle = reflow._rs
reflow.mode = "builtin"

-- reflow_builtin(range) reflows the RANGE lines, ignoring the '[ '] marks.
vim.bo.textwidth = 40
vim.bo.filetype = "lua"
vim.bo.comments = ":--"
vim.bo.formatoptions = "tcqj"
vim.bo.indentexpr = ""
vim.bo.formatexpr = ""
local short = "-- short"
local long = "-- " .. string.rep("word ", 20)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { short, long })
-- Point the change marks at line 1 (the short line) to prove they are ignored.
vim.api.nvim_buf_set_mark(0, "[", 1, 0, {})
vim.api.nvim_buf_set_mark(0, "]", 1, #short - 1, {})
reflow.reflow_builtin({ start = { 2, 0 }, ["end"] = { 2, #long - 1 } })
local rb = vim.api.nvim_buf_get_lines(0, 0, -1, false)
check("reflow_builtin(range) wrapped the range line", #rb > 2, #rb)
check("reflow_builtin(range) left line 1 intact", rb[1] == short, rb[1])

-- conservative python with autopep8 unavailable -> reflow_builtin(range).
local got_range
reflow._rb_real = reflow.reflow_builtin
reflow.reflow_builtin = function(r) got_range = r or "NIL" end
package.loaded["conform"] = {
  format = function() end,
  get_formatter_info = function(name) return { available = name ~= "autopep8" } end,
}
reflow.mode = "conservative"
vim.bo.filetype = "python"
local crng = { start = { 3, 0 }, ["end"] = { 5, 2 } }
reflow.restyle(crng)
check("conservative fallback passes range to reflow_builtin", got_range == crng, tostring(got_range))
reflow.reflow_builtin = reflow._rb_real
reflow.mode = "builtin"
package.loaded["conform"] = nil

-- opfunc reads '[ '] marks into a range and honors _pending_restyle.
local op_range, op_force
reflow._dr_real = reflow.dispatch_range
reflow.dispatch_range = function(r, f) op_range = r; op_force = f end
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "l1", "l2", "l3", "l4" })
vim.api.nvim_buf_set_mark(0, "[", 2, 0, {})
vim.api.nvim_buf_set_mark(0, "]", 3, 1, {})
reflow._pending_restyle = false
reflow.opfunc()
check("opfunc range start from '[ mark", op_range and op_range.start[1] == 2, op_range and op_range.start[1])
check("opfunc range end from '] mark", op_range and op_range["end"][1] == 3, op_range and op_range["end"][1])
check("opfunc passes _pending_restyle false", op_force == false, tostring(op_force))
reflow._pending_restyle = true
reflow.opfunc()
check("opfunc passes _pending_restyle true", op_force == true, tostring(op_force))
reflow.dispatch_range = reflow._dr_real
reflow._pending_restyle = false

-- dispatch_range reports whether a synchronous reflow ran, so the visual maps
-- know to reselect via the '[ '] change marks (reflow) vs gv (async restyle).
reflow._rb3 = reflow.reflow_builtin
reflow._rs3 = reflow.restyle
reflow.reflow_builtin = function() return true end
reflow.restyle = function() return false end
reflow.mode = "builtin"
check("dispatch_range returns true for reflow", reflow.dispatch_range({ start = { 1, 0 }, ["end"] = { 1, 1 } }, false) == true)
reflow.mode = "lsp"
check("dispatch_range returns false for restyle", reflow.dispatch_range({ start = { 1, 0 }, ["end"] = { 1, 1 } }, false) == false)
reflow.reflow_builtin = reflow._rb3
reflow.restyle = reflow._rs3
reflow.mode = "builtin"

-- reflow_builtin returns true (it reflowed synchronously; '[ '] are valid).
vim.bo.textwidth = 40
vim.bo.filetype = "lua"
vim.bo.comments = ":--"
vim.bo.formatoptions = "tcqj"
vim.bo.indentexpr = ""
vim.bo.formatexpr = ""
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "-- " .. string.rep("word ", 20) })
vim.api.nvim_buf_set_mark(0, "[", 1, 0, {})
vim.api.nvim_buf_set_mark(0, "]", 1, 1, {})
check("reflow_builtin returns true", reflow.reflow_builtin() == true)

-- reflow_builtin(range) must work even when called from active visual mode.
-- The visual gq/gQ/,=q maps fire while still IN visual mode (mode == "V"); a
-- bare `normal! VGgq` would then TOGGLE visual mode off and reflow nothing.
vim.bo.textwidth = 40
vim.bo.filetype = "lua"
vim.bo.comments = ":--"
vim.bo.formatoptions = "tcqj"
vim.bo.indentexpr = ""
vim.bo.formatexpr = ""
local vlong = "-- " .. string.rep("word ", 20)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { vlong, "second line" })
-- Enter visual-line mode over line 1 so reflow_builtin runs mid-visual.
vim.api.nvim_feedkeys(
  vim.api.nvim_replace_termcodes("ggV", true, false, true), "x", false)
reflow.reflow_builtin({ start = { 1, 0 }, ["end"] = { 1, #vlong - 1 } })
local vb = vim.api.nvim_buf_get_lines(0, 0, -1, false)
check("reflow_builtin(range) wraps from active visual mode", #vb > 2, #vb)
vim.api.nvim_feedkeys(
  vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

if #failures > 0 then
  io.write("\n" .. #failures .. " failure(s)\n")
  vim.cmd("cquit 1")
end
io.write("\nall passed\n")
