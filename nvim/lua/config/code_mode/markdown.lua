-- Markdown code-mode helpers: headings, links, tables, emphasis, rendering.
local M = {}

local shared = require("config.code_mode.shared")

local function visual_positions()
  local start_pos = vim.api.nvim_buf_get_mark(0, "<")
  local end_pos = vim.api.nvim_buf_get_mark(0, ">")

  local start_row, start_col = start_pos[1], start_pos[2]
  local end_row, end_col = end_pos[1], end_pos[2]

  if start_row == 0 or end_row == 0 then
    return nil
  end

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  return {
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }
end

local function surround_visual_selection(prefix, suffix)
  local range = visual_positions()
  if not range then
    return
  end

  vim.api.nvim_buf_set_text(0, range.end_row - 1, range.end_col + 1, range.end_row - 1, range.end_col + 1, { suffix })
  vim.api.nvim_buf_set_text(0, range.start_row - 1, range.start_col, range.start_row - 1, range.start_col, { prefix })
end

local function insert_pair(prefix, suffix)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { prefix .. suffix })
  vim.api.nvim_win_set_cursor(0, { row, col + #prefix })
end

local function insert_linewise_prefix(prefix)
  local range = visual_positions()
  if range then
    local lines = vim.api.nvim_buf_get_lines(0, range.start_row - 1, range.end_row, false)
    for index, line in ipairs(lines) do
      lines[index] = prefix .. line
    end
    vim.api.nvim_buf_set_lines(0, range.start_row - 1, range.end_row, false, lines)
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { prefix .. line })
  vim.api.nvim_win_set_cursor(0, { row, #prefix })
end

local function markdown_wrap_pair(prefix, suffix)
  return {
    normal = function()
      insert_pair(prefix, suffix)
    end,
    visual = function()
      surround_visual_selection(prefix, suffix)
    end,
  }
end

function M.markdown_follow_thing()
  local url = vim.fn.expand("<cfile>")
  if url == "" then
    vim.notify("No link or path detected at point.", vim.log.levels.INFO)
    return
  end

  if vim.ui.open then
    vim.ui.open(url)
  else
    vim.cmd.normal({ "gx", bang = true })
  end
end

-- markdown_heading(level) returns a closure that rewrites the current line to a
-- heading of that level, preserving the existing heading text.
function M.markdown_heading(level)
  return function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
    local content = vim.trim(line:gsub("^%s*#+%s*", ""))
    local prefix = string.rep("#", level) .. " "
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { prefix .. content })
    vim.api.nvim_win_set_cursor(0, { row, #prefix })
  end
end

function M.markdown_insert_horizontal_rule()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  shared.insert_lines({ "", "---", "" }, {
    row = row,
    cursor_line = 2,
    cursor_col = 0,
  })
end

function M.markdown_insert_link()
  insert_pair("[", "](url)")
end

function M.markdown_insert_image()
  insert_pair("![", "](image.png)")
end

function M.markdown_insert_footnote()
  insert_pair("[^", "]")
end

function M.markdown_insert_wiki_link()
  insert_pair("[[", "]]")
end

function M.markdown_insert_table()
  shared.insert_lines({
    "| Column 1 | Column 2 |",
    "| -------- | -------- |",
    "|          |          |",
  }, {
    cursor_line = 1,
    cursor_col = 2,
  })
end

function M.markdown_insert_checkbox()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  local prefix = shared.current_indent(0)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { prefix .. "- [ ] " .. vim.trim(line) })
  vim.api.nvim_win_set_cursor(0, { row, #prefix + 6 })
end

function M.markdown_toggle_render()
  require("render-markdown").buf_toggle()
end

function M.markdown_preview()
  require("render-markdown").preview()
end

function M.markdown_render_buffer()
  require("render-markdown").buf_enable()
end

function M.markdown_bold()
  markdown_wrap_pair("**", "**").normal()
end

function M.markdown_bold_visual()
  markdown_wrap_pair("**", "**").visual()
end

function M.markdown_italic()
  markdown_wrap_pair("*", "*").normal()
end

function M.markdown_italic_visual()
  markdown_wrap_pair("*", "*").visual()
end

function M.markdown_code()
  markdown_wrap_pair("`", "`").normal()
end

function M.markdown_code_visual()
  markdown_wrap_pair("`", "`").visual()
end

function M.markdown_blockquote()
  insert_linewise_prefix("> ")
end

return M
