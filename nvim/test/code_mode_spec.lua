-- Headless test harness for config.code_mode pure helpers.
-- Run: nvim --headless -u NONE -l nvim/test/code_mode_spec.lua
--
-- Covers the buffer-content-derived helpers (test targets, FQCNs, indentation,
-- shell template rendering) that are pure given the buffer and cursor. The
-- terminal/keymap wiring in setup() is exercised interactively, not here.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/code_mode_spec.lua$", "")
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

local shared = require("config.code_mode.shared")
local go = require("config.code_mode.go")
local java = require("config.code_mode.java")
local shell = require("config.code_mode.shell")
local python_debug = require("config.code_mode.python_debug")

-- Helper: load lines into the current buffer and park the cursor on a row.
local function set_buf(lines, row)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row or #lines, 0 })
end

-- shared.indent_prefix(): N shiftwidths of spaces (default sw=2 under -u NONE).
do
  vim.bo.shiftwidth = 4
  check("indent_prefix 1 level @ sw4", shared.indent_prefix(1) == "    ", "[" .. shared.indent_prefix(1) .. "]")
  check("indent_prefix 2 levels @ sw4", shared.indent_prefix(2) == "        ", shared.indent_prefix(2))
  check("indent_prefix 0 levels", shared.indent_prefix(0) == "", "[" .. shared.indent_prefix(0) .. "]")
  vim.bo.shiftwidth = 2
end

-- shared.current_indent(): leading whitespace of the cursor line.
do
  set_buf({ "no indent", "    four spaces", "\ttab" }, 2)
  check("current_indent reads spaces", shared.current_indent(0) == "    ", "[" .. shared.current_indent(0) .. "]")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  check("current_indent empty for col0", shared.current_indent(0) == "", "[" .. shared.current_indent(0) .. "]")
end

-- go.go_test_name(): nearest Test/Benchmark/Example func above the cursor.
do
  set_buf({
    "package main",
    "func TestFoo(t *testing.T) {",
    "  x := 1",
    "}",
    "func helper() {}",
  }, 3)
  check("go_test_name finds TestFoo", go.go_test_name() == "TestFoo", go.go_test_name())

  set_buf({ "func BenchmarkBar(b *testing.B) {", "  _ = 1" }, 2)
  check("go_test_name finds Benchmark", go.go_test_name() == "BenchmarkBar", go.go_test_name())

  set_buf({ "package main", "func plain() {}" }, 2)
  check("go_test_name nil when no test", go.go_test_name() == nil, go.go_test_name())
end

-- go.go_import_line(): 1-indexed line of the first import.
do
  set_buf({ "package main", "", "import (", '  "fmt"', ")" }, 1)
  check("go_import_line finds block", go.go_import_line() == 3, go.go_import_line())
  set_buf({ "package main", 'import "fmt"' }, 1)
  check("go_import_line finds single", go.go_import_line() == 2, go.go_import_line())
  set_buf({ "package main", "var x = 1" }, 1)
  check("go_import_line nil when none", go.go_import_line() == nil, go.go_import_line())
end

-- java class/test-class names derive from the buffer's file name.
do
  vim.api.nvim_buf_set_name(0, "/proj/src/main/java/com/example/Widget.java")
  check("java_class_name from file", java.java_class_name(0) == "Widget", java.java_class_name(0))
  check("java_test_class appends Test", java.java_test_class_name(0) == "WidgetTest", java.java_test_class_name(0))
  vim.api.nvim_buf_set_name(0, "/proj/src/test/java/com/example/WidgetTest.java")
  check("java_test_class keeps existing Test", java.java_test_class_name(0) == "WidgetTest", java.java_test_class_name(0))
end

-- java.java_package_name() + java_fqcn() read the package declaration.
do
  vim.api.nvim_buf_set_name(0, "/proj/src/main/java/com/example/Widget.java")
  set_buf({ "package com.example;", "", "public class Widget {}" }, 3)
  check("java_package_name", java.java_package_name(0) == "com.example", java.java_package_name(0))
  check("java_fqcn source class", java.java_fqcn(0, false) == "com.example.Widget", java.java_fqcn(0, false))
  check("java_fqcn test class", java.java_fqcn(0, true) == "com.example.WidgetTest", java.java_fqcn(0, true))
  -- No package declaration -> bare class name.
  set_buf({ "public class Widget {}" }, 1)
  check("java_fqcn no package", java.java_fqcn(0, false) == "Widget", java.java_fqcn(0, false))
end

-- java.java_test_method_name(): finds the nearest test method walking UPWARD
-- from the cursor. A method counts as a test if it is named test* OR carries a
-- @Test annotation (checked by an upward lookahead from the signature, which
-- tolerates other annotations and blank lines between @Test and the signature).
do
  vim.api.nvim_buf_set_name(0, "/proj/src/test/java/WidgetTest.java")
  set_buf({ "  public void testThing() {", "    int x = 1;" }, 2)
  check("java_test_method via test prefix", java.java_test_method_name(0) == "testThing", java.java_test_method_name(0))
  -- @Test + test-prefixed name.
  set_buf({ "  @Test", "  public void testWorks() {", "    assertTrue(true);" }, 3)
  check("java_test_method @Test + test name", java.java_test_method_name(0) == "testWorks", java.java_test_method_name(0))
  -- @Test + non-test name: now detected via the annotation lookahead.
  set_buf({ "  @Test", "  public void shouldWork() {", "    assertTrue(true);" }, 3)
  check("java_test_method @Test + non-test name", java.java_test_method_name(0) == "shouldWork", java.java_test_method_name(0))
  -- @Test with an intervening annotation before the signature.
  set_buf({ "  @Test", '  @DisplayName("works")', "  public void verifies() {", "    assertTrue(true);" }, 4)
  check("java_test_method @Test + extra annotation", java.java_test_method_name(0) == "verifies", java.java_test_method_name(0))
  -- @Test with a blank line before the signature.
  set_buf({ "  @Test", "", "  public void runs() {", "    assertTrue(true);" }, 4)
  check("java_test_method @Test + blank line", java.java_test_method_name(0) == "runs", java.java_test_method_name(0))
  -- A plain (non-test, non-annotated) method is not picked up.
  set_buf({ "  public void helper() {", "    int x = 1;" }, 2)
  check("java_test_method ignores plain method", java.java_test_method_name(0) == nil, java.java_test_method_name(0))
  -- An @Override (non-@Test) annotated, non-test-named method is not a test.
  set_buf({ "  @Override", "  public void setUp() {", "    init();" }, 3)
  check("java_test_method ignores @Override non-test", java.java_test_method_name(0) == nil, java.java_test_method_name(0))
end

-- python_debug.python_test_target(): nearest test fn + enclosing Test class,
-- expressed as a pytest node id against the buffer file.
do
  vim.api.nvim_buf_set_name(0, "/proj/tests/test_mod.py")
  set_buf({
    "class TestThing:",
    "    def test_alpha(self):",
    "        assert True",
  }, 3)
  local node, has = python_debug.python_test_target()
  check("py_test_target node id", node == "/proj/tests/test_mod.py::TestThing::test_alpha", node)
  check("py_test_target has_test true", has == true, has)

  -- A top-level test function with no class.
  set_buf({ "def test_beta():", "    assert 1" }, 2)
  local node2, has2 = python_debug.python_test_target()
  check("py_test_target classless", node2 == "/proj/tests/test_mod.py::test_beta", node2)
  check("py_test_target classless has_test", has2 == true, has2)

  -- Not on a test -> file only, has_test false.
  set_buf({ "def helper():", "    return 1" }, 2)
  local node3, has3 = python_debug.python_test_target()
  check("py_test_target no test has_test false", has3 == false, has3)
  check("py_test_target no test node is file", node3 == "/proj/tests/test_mod.py", node3)
end

-- shell._render_block(): $BASE$/$BODY$ anchor substitution (pure).
do
  local out = shell._render_block({ "$BASE$if x; then", "$BODY$", "$BASE$fi" }, "  ", "    ")
  check("render_block base line 1", out[1] == "  if x; then", out[1])
  check("render_block body blank line", out[2] == "    ", "[" .. out[2] .. "]")
  check("render_block base line 3", out[3] == "  fi", out[3])
  -- $BODY$ prefix (not bare) keeps trailing text after the anchor.
  local out2 = shell._render_block({ "$BODY$;;" }, "", "    ")
  check("render_block body prefix keeps text", out2[1] == "    ;;", "[" .. out2[1] .. "]")
end

-- shell._backslash_lines(): append " \" to non-blank, non-continued lines.
do
  local out = shell._backslash_lines({ "cmd one", "  ", "cmd two \\", "cmd three  " })
  check("backslash appends to plain", out[1] == "cmd one \\", out[1])
  check("backslash skips blank", out[2] == "  ", "[" .. out[2] .. "]")
  check("backslash skips already-continued", out[3] == "cmd two \\", out[3])
  check("backslash trims then appends", out[4] == "cmd three \\", out[4])
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
