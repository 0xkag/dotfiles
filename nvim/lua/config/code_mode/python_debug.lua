-- Python debugging helpers: terminal-driven ipdb / pytest --trace runs.
-- (See DEBUGGING_PYTHON.md for why this is terminal-first, not DAP.)
local M = {}

local shared = require("config.code_mode.shared")
local python_env = require("config.python")
local tools = require("config.tools")
local util = require("config.util")

local function python_debug_python()
  local status = python_env.module_status("ipdb", 0)
  if status.available then
    return status.python
  end

  vim.notify("Install ipdb in the active Python environment to use debugging.\n" .. status.detail, vim.log.levels.WARN)
  return nil
end

-- Find the nearest pytest node id ("file::Class::test_fn") above the cursor.
-- Returns (node, has_test). Pure given buffer contents; the file path comes
-- from the buffer name.
function M.python_test_target()
  local file = shared.current_file(0)
  if not file then
    return nil, false
  end

  local class_name
  local test_name

  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  for lnum = cursor, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
    if not test_name then
      test_name = line:match("^%s*def%s+(test[%w_]+)%s*%(")
    end
    if not class_name then
      class_name = line:match("^%s*class%s+([%w_]+)%s*[%(:]")
      if class_name and not class_name:match("^Test") then
        class_name = nil
      end
    end

    if test_name and class_name then
      break
    end
  end

  local node = file
  if class_name then
    node = node .. "::" .. class_name
  end
  if test_name then
    node = node .. "::" .. test_name
  end

  return node, test_name ~= nil
end

function M.python_debug_file()
  local python = python_debug_python()
  local file = shared.current_file(0)
  if not python or not file then
    return
  end

  shared.run_command("python debug", shared.shellescape(python) .. " -m ipdb " .. shared.shellescape(file), {
    cwd = shared.current_dir(0),
    last_key = "python_debug",
  })
end

function M.python_debug_file_tests()
  local python = python_debug_python()
  local file = shared.current_file(0)
  if not python or not file then
    return
  end

  if not tools.available("pytest") then
    vim.notify("Install pytest in the active Python environment to debug tests.", vim.log.levels.WARN)
    return
  end

  shared.run_command("python debug", shared.shellescape(python) .. " -m pytest --trace " .. shared.shellescape(file), {
    cwd = util.project_root(0),
    last_key = "python_debug",
  })
end

function M.python_debug_nearest_test()
  local python = python_debug_python()
  if not python then
    return
  end

  if not tools.available("pytest") then
    vim.notify("Install pytest in the active Python environment to debug tests.", vim.log.levels.WARN)
    return
  end

  local node, has_test = M.python_test_target()
  if not node or not has_test then
    vim.notify("No Python test function found near the cursor.", vim.log.levels.INFO)
    return
  end

  shared.run_command("python debug", shared.shellescape(python) .. " -m pytest --trace " .. shared.shellescape(node), {
    cwd = util.project_root(0),
    last_key = "python_debug",
  })
end

function M.python_debug_last()
  shared.rerun_last("python_debug")
end

return M
