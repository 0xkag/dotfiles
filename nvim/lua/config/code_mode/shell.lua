-- Shell (bash/sh/zsh) code-mode helpers: shebang, control-flow templates,
-- line-continuation backslashes. Some templates are gated on the shell dialect.
local M = {}

local shared = require("config.code_mode.shared")

local function shell_filetype()
  return vim.bo.filetype
end

local function shell_name()
  local ft = shell_filetype()
  if ft == "bash" or ft == "zsh" or ft == "fish" then
    return ft
  end

  return "sh"
end

local function shell_supports_select()
  local ft = shell_filetype()
  return ft == "bash" or ft == "zsh"
end

local function shell_supports_repeat()
  return shell_filetype() == "zsh"
end

-- Render a template with $BASE$ / $BODY$ indentation anchors and insert it.
-- $BODY$ on its own line emits a blank body line; $BASE$/$BODY$ prefixes get
-- the matching indent. Pure transform exposed for tests as M._render_block.
local function render_block(lines, base, body)
  local rendered = {}
  for _, line in ipairs(lines) do
    if line == "$BODY$" then
      table.insert(rendered, body)
    else
      if vim.startswith(line, "$BASE$") then
        line = base .. line:sub(7)
      elseif vim.startswith(line, "$BODY$") then
        line = body .. line:sub(7)
      end
      table.insert(rendered, line)
    end
  end
  return rendered
end
M._render_block = render_block

local function insert_shell_block(lines, opts)
  opts = opts or {}
  local base = shared.current_indent(0)
  local body = base .. shared.indent_prefix(1)

  shared.insert_lines(render_block(lines, base, body), {
    cursor_line = opts.cursor_line,
    cursor_col = opts.cursor_col or #body,
  })
end

local function notify_unsupported(feature)
  vim.notify(feature .. " is not supported for " .. shell_name() .. " buffers.", vim.log.levels.INFO)
end

-- Append " \" to non-blank lines in [start_line, end_line] that don't already
-- end in a backslash. Pure transform exposed for tests as M._backslash_lines.
local function backslash_lines(lines)
  for index, line in ipairs(lines) do
    if line:match("%S") and not line:match("\\%s*$") then
      lines[index] = line:gsub("%s*$", "") .. " \\"
    end
  end
  return lines
end
M._backslash_lines = backslash_lines

local function shell_backslash_range(start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  backslash_lines(lines)
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
end

local function shell_visual_range()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  if start_line == 0 or end_line == 0 then
    start_line = vim.api.nvim_win_get_cursor(0)[1]
    end_line = start_line
  end

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  return start_line, end_line
end

function M.shell_insert_shebang()
  local shebang = "#!/usr/bin/env " .. shell_name()
  local first = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
  if first == shebang then
    vim.notify("Buffer already has the correct shebang.", vim.log.levels.INFO)
    return
  end

  if first:match("^#!") then
    vim.notify("Buffer already has a shebang.", vim.log.levels.INFO)
    return
  end

  if vim.api.nvim_buf_line_count(0) == 1 and first == "" then
    vim.api.nvim_buf_set_lines(0, 0, 1, false, { shebang, "" })
  else
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { shebang, "" })
  end

  vim.api.nvim_win_set_cursor(0, {
    math.min(3, vim.api.nvim_buf_line_count(0)),
    0,
  })
end

function M.shell_insert_case()
  insert_shell_block({
    '$BASE$case "$1" in',
    "$BODY$pattern)",
    "$BODY$" .. shared.indent_prefix(1) .. ";;",
    "$BASE$esac",
  }, {
    cursor_line = 2,
    cursor_col = #shared.current_indent(0) + #shared.indent_prefix(1),
  })
end

function M.shell_insert_if()
  insert_shell_block({
    "$BASE$if [ condition ]; then",
    "$BODY$",
    "$BASE$fi",
  }, {
    cursor_line = 2,
  })
end

function M.shell_insert_function()
  local base = shared.current_indent(0)
  insert_shell_block({
    "$BASE$name() {",
    "$BODY$",
    "$BASE$}",
  }, {
    cursor_line = 1,
    cursor_col = #base,
  })
end

function M.shell_insert_for()
  insert_shell_block({
    '$BASE$for item in "$@"; do',
    "$BODY$",
    "$BASE$done",
  }, {
    cursor_line = 2,
  })
end

function M.shell_insert_indexed_for()
  if not shell_supports_select() then
    notify_unsupported("Indexed for loops")
    return
  end

  insert_shell_block({
    "$BASE$for ((i = 0; i < count; i++)); do",
    "$BODY$",
    "$BASE$done",
  }, {
    cursor_line = 2,
  })
end

function M.shell_insert_while()
  insert_shell_block({
    "$BASE$while condition; do",
    "$BODY$",
    "$BASE$done",
  }, {
    cursor_line = 2,
  })
end

function M.shell_insert_repeat()
  if not shell_supports_repeat() then
    notify_unsupported("Repeat loops")
    return
  end

  insert_shell_block({
    "$BASE$repeat 10; do",
    "$BODY$",
    "$BASE$done",
  }, {
    cursor_line = 2,
  })
end

function M.shell_insert_select()
  if not shell_supports_select() then
    notify_unsupported("Select loops")
    return
  end

  insert_shell_block({
    "$BASE$select item in option1 option2; do",
    "$BODY$",
    "$BASE$done",
  }, {
    cursor_line = 2,
  })
end

function M.shell_insert_until()
  insert_shell_block({
    "$BASE$until condition; do",
    "$BODY$",
    "$BASE$done",
  }, {
    cursor_line = 2,
  })
end

function M.shell_insert_getopts()
  insert_shell_block({
    '$BASE$while getopts ":ab:" opt; do',
    '$BODY$case "$opt" in',
    "$BODY$" .. shared.indent_prefix(1) .. "a)",
    "$BODY$" .. shared.indent_prefix(2) .. ";;",
    "$BODY$" .. shared.indent_prefix(1) .. "b)",
    "$BODY$" .. shared.indent_prefix(2) .. ";;",
    "$BODY$" .. shared.indent_prefix(1) .. "*)",
    "$BODY$" .. shared.indent_prefix(2) .. ";;",
    "$BODY$esac",
    "$BASE$done",
  }, {
    cursor_line = 3,
    cursor_col = #shared.current_indent(0) + #shared.indent_prefix(2),
  })
end

function M.shell_add_backslashes()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  shell_backslash_range(line, line)
end

function M.shell_add_backslashes_visual()
  local start_line, end_line = shell_visual_range()
  shell_backslash_range(start_line, end_line)
end

return M
