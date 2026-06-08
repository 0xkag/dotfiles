-- Shared helpers for the language code-mode submodules.
--
-- Holds the cross-language terminal/last-command state and the small utility
-- functions (buffer paths, indentation, terminal command runner, which-key
-- label registration) that the per-language modules build on.
local M = {}

local uv = vim.uv or vim.loop
local util = require("config.util")

local terminals = {}
local last_commands = {}

function M.current_file(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  return vim.fs.normalize(name)
end

function M.current_dir(bufnr)
  local file = M.current_file(bufnr)
  if not file then
    return util.project_root(bufnr)
  end

  return vim.fs.dirname(file)
end

function M.file_exists(path)
  return path and uv.fs_stat(path) ~= nil
end

function M.shellescape(value)
  return vim.fn.shellescape(value)
end

local function shiftwidth(bufnr)
  bufnr = bufnr or 0
  local width = vim.bo[bufnr].shiftwidth
  if width == 0 then
    width = vim.bo[bufnr].tabstop
  end

  if width == 0 then
    width = 2
  end

  return width
end
M.shiftwidth = shiftwidth

function M.indent_prefix(levels, bufnr)
  return string.rep(" ", shiftwidth(bufnr) * (levels or 0))
end

function M.current_indent(bufnr)
  bufnr = bufnr or 0
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local prefix = line:match("^(%s*)")
  return prefix or ""
end

-- Register buffer-local which-key labels once which-key has loaded.
--
-- which-key shows a node's spec label in preference to the real keymap desc, and
-- within a node the last-registered spec wins. The global localleader group labels
-- are added during which-key's own (VeryLazy) load. A `git commit` / `git rebase -i`
-- launches a fresh Neovim whose gitcommit/gitrebase FileType fires *before* that
-- load, so a direct wk.add() would be overridden by the global groups. Register once
-- which-key has loaded (immediately if it already has) so our buffer-local labels win.
function M.register_git_editor_labels(buf, specs)
  local function apply()
    local ok, wk = pcall(require, "which-key")
    if not ok or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    wk.add(specs)
  end

  local cfg_ok, wk_config = pcall(require, "which-key.config")
  if cfg_ok and wk_config.loaded then
    apply()
  else
    -- which-key not loaded yet: register after lazy.nvim loads it.
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyLoad",
      callback = function(ev)
        if ev.data ~= "which-key.nvim" then
          return
        end
        vim.schedule(apply)
        return true -- which-key handled; remove this one-shot autocmd
      end,
    })
  end
end

function M.insert_lines(lines, opts)
  opts = opts or {}
  local row = opts.row
  if row == nil then
    row = vim.api.nvim_win_get_cursor(0)[1]
  end

  vim.api.nvim_buf_set_lines(0, row, row, false, lines)

  if opts.cursor_line then
    vim.api.nvim_win_set_cursor(0, {
      row + opts.cursor_line,
      opts.cursor_col or 0,
    })
  end
end

function M.organize_imports()
  vim.lsp.buf.code_action({
    apply = true,
    context = {
      only = { "source.organizeImports" },
      diagnostics = vim.diagnostic.get(0),
    },
  })
end

local function terminal(name, cwd)
  local Terminal = require("toggleterm.terminal").Terminal
  local term = terminals[name]

  if not term then
    term = Terminal:new({
      close_on_exit = false,
      direction = "horizontal",
      dir = cwd,
      display_name = name,
      hidden = true,
    })
    terminals[name] = term
  end

  return term
end

function M.run_command(name, command, opts)
  opts = opts or {}
  local cwd = opts.cwd or util.project_root(opts.bufnr or 0)
  local term = terminal(name, cwd)

  if term:is_open() then
    term:change_dir(cwd, false)
  else
    term.dir = cwd
    term:open()
  end

  term:send({ "clear", command }, false)
  last_commands[opts.last_key or name] = {
    command = command,
    cwd = cwd,
    name = name,
  }
end

function M.rerun_last(key)
  local last = last_commands[key]
  if not last then
    vim.notify("No previous command recorded for " .. key .. ".", vim.log.levels.INFO)
    return
  end

  M.run_command(last.name, last.command, {
    cwd = last.cwd,
    last_key = key,
  })
end

function M.project_command(name, command, opts)
  opts = opts or {}
  M.run_command(name, command, {
    cwd = opts.cwd or util.project_root(0),
    last_key = opts.last_key or name,
  })
end

function M.edit_if_exists(path)
  if not M.file_exists(path) then
    vim.notify("Alternate file not found: " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.nearest_matching_line(bufnr, match)
  bufnr = bufnr or 0
  local cursor = vim.api.nvim_win_get_cursor(0)[1]

  for lnum = cursor, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
    local value = match(line)
    if value then
      return value
    end
  end

  return nil
end

return M
