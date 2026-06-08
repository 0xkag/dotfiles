-- Headless test harness for config.lsp_util pure helpers.
-- Run: nvim --headless -u NONE -l nvim/test/lsp_util_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/lsp_util_spec.lua$", "")
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

local lsp_util = require("config.lsp_util")

-- clean_label(): name=default placeholder body, types stripped.
do
  check("clean_label type+default", lsp_util.clean_label("x: int = 3") == "x=3", lsp_util.clean_label("x: int = 3"))
  check("clean_label default only", lsp_util.clean_label("y=5") == "y=5", lsp_util.clean_label("y=5"))
  check("clean_label type only", lsp_util.clean_label("z: int") == "z", lsp_util.clean_label("z: int"))
  check("clean_label bare", lsp_util.clean_label("w") == "w", lsp_util.clean_label("w"))
  check("clean_label trims bare", lsp_util.clean_label("  q  ") == "q", "[" .. lsp_util.clean_label("  q  ") .. "]")
end

-- bare_name(): identifier with leading */** and type/default stripped.
do
  check("bare_name plain", lsp_util.bare_name("x") == "x", lsp_util.bare_name("x"))
  check("bare_name with type", lsp_util.bare_name("x: int = 1") == "x", lsp_util.bare_name("x: int = 1"))
  check("bare_name star args", lsp_util.bare_name("*args") == "args", lsp_util.bare_name("*args"))
  check("bare_name double star", lsp_util.bare_name("**kwargs") == "kwargs", lsp_util.bare_name("**kwargs"))
end

-- is_kwargable(): excludes separators and *args/**kwargs.
do
  check("is_kwargable normal", lsp_util.is_kwargable("x: int") == true)
  check("is_kwargable rejects star sep", lsp_util.is_kwargable("*") == false)
  check("is_kwargable rejects slash sep", lsp_util.is_kwargable("/") == false)
  check("is_kwargable rejects *args", lsp_util.is_kwargable("*args") == false)
  check("is_kwargable rejects **kwargs", lsp_util.is_kwargable("**kwargs") == false)
end

-- param_label(): literal string label, or offset pair into sig.label.
do
  check("param_label literal string", lsp_util.param_label({ label = "f(a, b)" }, { label = "a" }) == "a")
  -- Offsets are [start, end) into the signature label; LSP start is 0-based.
  local sig = { label = "f(alpha, beta)" }
  local got = lsp_util.param_label(sig, { label = { 2, 7 } })
  check("param_label offset pair", got == "alpha", got)
end

-- count_edits(): totals files + edits across changes and documentChanges.
do
  local files, total = lsp_util.count_edits({
    changes = {
      ["file:///a.lua"] = { {}, {} },
      ["file:///b.lua"] = { {} },
    },
  })
  check("count_edits changes file count", #files == 2, #files)
  check("count_edits changes total", total == 3, total)

  local files2, total2 = lsp_util.count_edits({
    documentChanges = {
      { textDocument = { uri = "file:///c.lua" }, edits = { {}, {}, {} } },
      { textDocument = { uri = "file:///d.lua" }, edits = { {} } },
    },
  })
  check("count_edits docChanges file count", #files2 == 2, #files2)
  check("count_edits docChanges total", total2 == 4, total2)

  local f3, t3 = lsp_util.count_edits({})
  check("count_edits empty files", #f3 == 0, #f3)
  check("count_edits empty total", t3 == 0, t3)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
