-- Headless test harness for config.util pure logic.
-- Run: nvim --headless -u NONE -l nvim/test/util_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/util_spec.lua$", "")
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

local util = require("config.util")

-- literal_pattern(): builds a \V (very-nomagic) search pattern, escaping the
-- search separator and backslash, and turning real newlines into \n atoms.
do
  check("literal_pattern prefixes \\V", util.literal_pattern("abc") == [[\Vabc]], util.literal_pattern("abc"))
  check("literal_pattern escapes slash", util.literal_pattern("a/b") == [[\Va\/b]], util.literal_pattern("a/b"))
  check("literal_pattern escapes backslash", util.literal_pattern([[a\b]]) == [[\Va\\b]], util.literal_pattern([[a\b]]))
  check(
    "literal_pattern turns newline into \\n",
    util.literal_pattern("a\nb") == [[\Va\nb]],
    util.literal_pattern("a\nb")
  )
end

-- _to_absolute(): leaves absolute paths untouched, joins relative onto cwd.
do
  check("to_absolute keeps absolute", util._to_absolute("/x/y", "/cwd") == "/x/y", util._to_absolute("/x/y", "/cwd"))
  check(
    "to_absolute joins relative",
    util._to_absolute("a/b.lua", "/proj") == "/proj/a/b.lua",
    util._to_absolute("a/b.lua", "/proj")
  )
end

-- _parse_git_grep(): "file:lnum:col:text" with column, filename made absolute.
do
  local item = util._parse_git_grep("src/a.lua:12:4:local x = 1", "/proj")
  check("git_grep filename absolute", item and item.filename == "/proj/src/a.lua", item and item.filename)
  check("git_grep lnum", item and item.lnum == 12, item and item.lnum)
  check("git_grep col", item and item.col == 4, item and item.col)
  check("git_grep text", item and item.text == "local x = 1", item and item.text)
  -- A colon in the matched text must not be mis-split (lnum/col are numeric).
  local colon = util._parse_git_grep("a.lua:3:1:foo: bar", "/p")
  check("git_grep keeps colon in text", colon and colon.text == "foo: bar", colon and colon.text)
  check("git_grep rejects non-match", util._parse_git_grep("no colons here", "/p") == nil)
end

-- _parse_grep(): "file:lnum:text" (no column), filename left as-is.
do
  local item = util._parse_grep("src/a.lua:7:hit")
  check("grep filename verbatim", item and item.filename == "src/a.lua", item and item.filename)
  check("grep lnum", item and item.lnum == 7, item and item.lnum)
  check("grep text", item and item.text == "hit", item and item.text)
  check("grep has no col", item and item.col == nil, item and item.col)
  check("grep rejects non-match", util._parse_grep("nope") == nil)
end

-- _parse_global(): like grep, but resolves the filename against the root.
do
  local item = util._parse_global("a/b.c:9:def foo", "/root")
  check("global filename absolute", item and item.filename == "/root/a/b.c", item and item.filename)
  check("global lnum", item and item.lnum == 9, item and item.lnum)
  check("global rejects non-match", util._parse_global("bad", "/root") == nil)
end

-- _squeeze_line(): collapse interior whitespace runs to one space, preserve
-- leading indent, and reduce all-blank lines to empty.
do
  check("squeeze blank -> empty", util._squeeze_line("   ") == "", util._squeeze_line("   "))
  check("squeeze collapses interior", util._squeeze_line("a   b\tc") == "a b c", util._squeeze_line("a   b\tc"))
  check("squeeze preserves indent", util._squeeze_line("    a  b") == "    a b", util._squeeze_line("    a  b"))
  check("squeeze trims trailing", util._squeeze_line("a b   ") == "a b", util._squeeze_line("a b   "))
end

-- find_root() / project_root(): root marker walk and cwd fallback.
do
  check("find_root nil for empty", util.find_root("") == nil)
  check("find_root nil for nil", util.find_root(nil) == nil)
  -- This repo's nvim/ tree sits under a .git checkout, so a real path resolves.
  local root = util.find_root(here .. "/lua/config/util.lua")
  check("find_root finds a marker dir", type(root) == "string" and #root > 0, root)
  -- An unnamed buffer (no file) falls back to cwd.
  check("project_root falls back to cwd", util.project_root(0) == util.cwd(), util.project_root(0))
end

-- visual_selection_text(): linewise (V) joins whole lines; charwise pulls the
-- exact span. Drive it through real buffer marks.
do
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world", "second line", "third" })
  -- Linewise selection of lines 1..2 via the '< '> marks + visualmode V.
  vim.api.nvim_buf_set_mark(0, "<", 1, 0, {})
  vim.api.nvim_buf_set_mark(0, ">", 2, 0, {})
  vim.fn.setreg("/", "") -- unrelated, keep state clean
  -- Force visualmode() to report 'V' by entering and leaving linewise visual.
  vim.cmd("normal! 1GVj\27")
  local linewise = util.visual_selection_text()
  check("visual linewise joins lines", linewise == "hello world\nsecond line", linewise)

  -- Charwise selection: columns 0..4 on line 1 ("hello").
  vim.cmd("normal! 1G0v4l\27")
  local charwise = util.visual_selection_text()
  check("visual charwise span", charwise == "hello", charwise)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
