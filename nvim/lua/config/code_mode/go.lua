-- Go code-mode helpers: test running, coverage, imports, generate.
local M = {}

local shared = require("config.code_mode.shared")
local util = require("config.util")

-- Find the nearest enclosing Test/Benchmark/Example function name above the
-- cursor. Pure given the buffer contents under the cursor.
function M.go_test_name()
  return shared.nearest_matching_line(0, function(line)
    return line:match("^%s*func%s+(Test[%w_]+)%s*%(")
      or line:match("^%s*func%s+(Benchmark[%w_]+)%s*%(")
      or line:match("^%s*func%s+(Example[%w_]+)%s*%(")
  end)
end

-- 1-indexed line of the first `import` statement/block, or nil.
function M.go_import_line()
  local lines = vim.api.nvim_buf_get_lines(0, 0, math.min(vim.api.nvim_buf_line_count(0), 200), false)
  for index, line in ipairs(lines) do
    if line:match("^import%s*%(") or line:match('^import%s+[%(%"]') then
      return index
    end
  end

  return nil
end

function M.go_switch_test_file()
  local file = shared.current_file(0)
  if not file or vim.fn.fnamemodify(file, ":e") ~= "go" then
    return
  end

  local target
  if file:match("_test%.go$") then
    target = file:gsub("_test%.go$", ".go")
  else
    target = file:gsub("%.go$", "_test.go")
  end

  shared.edit_if_exists(target)
end

function M.go_goto_imports()
  local line = M.go_import_line()
  if not line then
    vim.notify("No import section found in this Go buffer.", vim.log.levels.INFO)
    return
  end

  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

function M.go_organize_imports()
  shared.organize_imports()
end

function M.go_test_nearest()
  local name = M.go_test_name()
  if not name then
    vim.notify("No Go test function found near the cursor.", vim.log.levels.INFO)
    return
  end

  shared.run_command("go test", "go test -run " .. shared.shellescape("^" .. name .. "$"), {
    cwd = shared.current_dir(0),
    last_key = "go_test",
  })
end

function M.go_test_package()
  shared.run_command("go test", "go test", {
    cwd = shared.current_dir(0),
    last_key = "go_test",
  })
end

function M.go_test_all()
  shared.run_command("go test", "go test ./...", {
    cwd = util.project_root(0),
    last_key = "go_test",
  })
end

function M.go_test_last()
  shared.rerun_last("go_test")
end

function M.go_coverage_package()
  shared.project_command("go coverage", "go test -coverprofile=.coverage.out && go tool cover -func=.coverage.out", {
    cwd = shared.current_dir(0),
    last_key = "go_coverage",
  })
end

function M.go_run_package()
  shared.run_command("go run", "go run .", {
    cwd = shared.current_dir(0),
    last_key = "go_run",
  })
end

function M.go_generate_file()
  local file = shared.current_file(0)
  if not file then
    return
  end

  shared.run_command("go generate", "go generate " .. shared.shellescape(vim.fn.fnamemodify(file, ":t")), {
    cwd = shared.current_dir(0),
    last_key = "go_generate",
  })
end

function M.go_generate_project()
  shared.run_command("go generate", "go generate ./...", {
    cwd = util.project_root(0),
    last_key = "go_generate",
  })
end

return M
