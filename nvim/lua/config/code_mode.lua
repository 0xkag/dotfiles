local M = {}

local uv = vim.uv or vim.loop
local tools = require("config.tools")
local util = require("config.util")

local terminals = {}
local last_commands = {}

local function current_file(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end

  return vim.fs.normalize(name)
end

local function current_dir(bufnr)
  local file = current_file(bufnr)
  if not file then
    return util.project_root(bufnr)
  end

  return vim.fs.dirname(file)
end

local function file_exists(path)
  return path and uv.fs_stat(path) ~= nil
end

local function shellescape(value)
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

local function indent_prefix(levels, bufnr)
  return string.rep(" ", shiftwidth(bufnr) * (levels or 0))
end

local function current_indent(bufnr)
  bufnr = bufnr or 0
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local prefix = line:match("^(%s*)")
  return prefix or ""
end

local function insert_lines(lines, opts)
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

local function organize_imports()
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

local function run_command(name, command, opts)
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

local function rerun_last(key)
  local last = last_commands[key]
  if not last then
    vim.notify("No previous command recorded for " .. key .. ".", vim.log.levels.INFO)
    return
  end

  run_command(last.name, last.command, {
    cwd = last.cwd,
    last_key = key,
  })
end

local function edit_if_exists(path)
  if not file_exists(path) then
    vim.notify("Alternate file not found: " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function nearest_matching_line(bufnr, match)
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

local function go_test_name()
  return nearest_matching_line(0, function(line)
    local name = line:match("^%s*func%s+(Test[%w_]+)%s*%(")
      or line:match("^%s*func%s+(Benchmark[%w_]+)%s*%(")
      or line:match("^%s*func%s+(Example[%w_]+)%s*%(")
    return name
  end)
end

local function go_import_line()
  local lines = vim.api.nvim_buf_get_lines(0, 0, math.min(vim.api.nvim_buf_line_count(0), 200), false)
  for index, line in ipairs(lines) do
    if line:match("^import%s*%(") or line:match("^import%s+[%(%\"]") then
      return index
    end
  end

  return nil
end

local function java_package_name(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(vim.api.nvim_buf_line_count(bufnr), 200), false)
  for _, line in ipairs(lines) do
    local package_name = line:match("^%s*package%s+([%w_.]+)%s*;")
    if package_name then
      return package_name
    end
  end

  return nil
end

local function java_class_name(bufnr)
  local file = current_file(bufnr)
  if not file then
    return nil
  end

  return vim.fn.fnamemodify(file, ":t:r")
end

local function java_test_class_name(bufnr)
  local class_name = java_class_name(bufnr)
  if not class_name then
    return nil
  end

  if class_name:match("Test$") then
    return class_name
  end

  return class_name .. "Test"
end

local function java_test_method_name(bufnr)
  local pending_test_annotation = false

  return nearest_matching_line(bufnr or 0, function(line)
    if line:match("^%s*@Test") then
      pending_test_annotation = true
      return nil
    end

    local name = line:match("^%s*[%w_<>,%[%]@%s]+%s+([%w_]+)%s*%b()%s*[{;]?")
    if not name then
      return nil
    end

    if pending_test_annotation or name:match("^test") then
      return name
    end

    return nil
  end)
end

local function java_build_tool(root)
  if not root then
    return nil
  end

  if file_exists(vim.fs.joinpath(root, "mvnw")) then
    return {
      name = "maven",
      root = root,
      shell = "./mvnw",
    }
  end

  if file_exists(vim.fs.joinpath(root, "pom.xml")) then
    if not tools.available("mvn") then
      vim.notify("Install maven or provide a project-local mvnw wrapper.", vim.log.levels.WARN)
      return nil
    end

    return {
      name = "maven",
      root = root,
      shell = "mvn",
    }
  end

  if file_exists(vim.fs.joinpath(root, "gradlew")) then
    return {
      name = "gradle",
      root = root,
      shell = "./gradlew",
    }
  end

  if file_exists(vim.fs.joinpath(root, "build.gradle")) or file_exists(vim.fs.joinpath(root, "build.gradle.kts")) then
    if not tools.available("gradle") then
      vim.notify("Install gradle or provide a project-local gradlew wrapper.", vim.log.levels.WARN)
      return nil
    end

    return {
      name = "gradle",
      root = root,
      shell = "gradle",
    }
  end

  vim.notify("No Maven or Gradle build found in this project.", vim.log.levels.INFO)
  return nil
end

local function java_fqcn(bufnr, use_test_class)
  local class_name = use_test_class and java_test_class_name(bufnr) or java_class_name(bufnr)
  if not class_name then
    return nil
  end

  local package_name = java_package_name(bufnr)
  if package_name and package_name ~= "" then
    return package_name .. "." .. class_name
  end

  return class_name
end

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

local function insert_shell_block(lines, opts)
  opts = opts or {}
  local base = current_indent(0)
  local body = base .. indent_prefix(1)
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

  insert_lines(rendered, {
    cursor_line = opts.cursor_line,
    cursor_col = opts.cursor_col or #body,
  })
end

local function notify_unsupported(feature)
  vim.notify(feature .. " is not supported for " .. shell_name() .. " buffers.", vim.log.levels.INFO)
end

local function shell_backslash_range(start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  for index, line in ipairs(lines) do
    if line:match("%S") and not line:match("\\%s*$") then
      lines[index] = line:gsub("%s*$", "") .. " \\"
    end
  end
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

function M.go_switch_test_file()
  local file = current_file(0)
  if not file or vim.fn.fnamemodify(file, ":e") ~= "go" then
    return
  end

  local target
  if file:match("_test%.go$") then
    target = file:gsub("_test%.go$", ".go")
  else
    target = file:gsub("%.go$", "_test.go")
  end

  edit_if_exists(target)
end

function M.go_goto_imports()
  local line = go_import_line()
  if not line then
    vim.notify("No import section found in this Go buffer.", vim.log.levels.INFO)
    return
  end

  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

function M.go_organize_imports()
  organize_imports()
end

function M.go_test_nearest()
  local name = go_test_name()
  if not name then
    vim.notify("No Go test function found near the cursor.", vim.log.levels.INFO)
    return
  end

  run_command("go test", "go test -run " .. shellescape("^" .. name .. "$"), {
    cwd = current_dir(0),
    last_key = "go_test",
  })
end

function M.go_test_package()
  run_command("go test", "go test", {
    cwd = current_dir(0),
    last_key = "go_test",
  })
end

function M.go_test_all()
  run_command("go test", "go test ./...", {
    cwd = util.project_root(0),
    last_key = "go_test",
  })
end

function M.go_test_last()
  rerun_last("go_test")
end

function M.go_run_package()
  run_command("go run", "go run .", {
    cwd = current_dir(0),
    last_key = "go_run",
  })
end

function M.go_generate_file()
  local file = current_file(0)
  if not file then
    return
  end

  run_command("go generate", "go generate " .. shellescape(vim.fn.fnamemodify(file, ":t")), {
    cwd = current_dir(0),
    last_key = "go_generate",
  })
end

function M.go_generate_project()
  run_command("go generate", "go generate ./...", {
    cwd = util.project_root(0),
    last_key = "go_generate",
  })
end

function M.java_switch_test_file()
  local file = current_file(0)
  if not file or vim.fn.fnamemodify(file, ":e") ~= "java" then
    return
  end

  local target = file
  if target:find("/src/test/java/", 1, true) then
    target = target:gsub("/src/test/java/", "/src/main/java/", 1)
    target = target:gsub("Test%.java$", ".java")
  elseif target:find("/src/main/java/", 1, true) then
    target = target:gsub("/src/main/java/", "/src/test/java/", 1)
    target = target:gsub("%.java$", "Test.java")
  else
    vim.notify("Current Java file is not in a Maven/Gradle source layout.", vim.log.levels.INFO)
    return
  end

  edit_if_exists(target)
end

function M.java_build_project()
  local tool = java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  local command = tool.name == "maven"
      and (tool.shell .. " -DskipTests compile")
    or (tool.shell .. " classes")

  run_command("java build", command, {
    cwd = tool.root,
    last_key = "java_build",
  })
end

function M.java_run_all_tests()
  local tool = java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  local command = tool.name == "maven"
      and (tool.shell .. " test")
    or (tool.shell .. " test")

  run_command("java test", command, {
    cwd = tool.root,
    last_key = "java_test",
  })
end

function M.java_run_class_tests()
  local tool = java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  local test_class = java_test_class_name(0)
  if not test_class then
    vim.notify("Unable to determine the Java test class.", vim.log.levels.INFO)
    return
  end

  local command
  if tool.name == "maven" then
    command = tool.shell .. " -Dtest=" .. shellescape(test_class) .. " test"
  else
    command = tool.shell .. " test --tests " .. shellescape(java_fqcn(0, true))
  end

  run_command("java test", command, {
    cwd = tool.root,
    last_key = "java_test",
  })
end

function M.java_run_nearest_test()
  local tool = java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  local test_class = java_test_class_name(0)
  local method = java_test_method_name(0)
  if not test_class or not method then
    vim.notify("No Java test method found near the cursor.", vim.log.levels.INFO)
    return
  end

  local command
  if tool.name == "maven" then
    command = tool.shell .. " -Dtest=" .. shellescape(test_class .. "#" .. method) .. " test"
  else
    command = tool.shell .. " test --tests " .. shellescape(java_fqcn(0, true) .. "." .. method)
  end

  run_command("java test", command, {
    cwd = tool.root,
    last_key = "java_test",
  })
end

function M.java_run_last_test()
  rerun_last("java_test")
end

function M.java_run_task()
  local tool = java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  vim.ui.input({
    prompt = tool.name == "maven" and "Maven task > " or "Gradle task > ",
  }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end

    run_command("java task", tool.shell .. " " .. input, {
      cwd = tool.root,
      last_key = "java_task",
    })
  end)
end

function M.java_organize_imports()
  organize_imports()
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
    '$BODY$pattern)',
    '$BODY$' .. indent_prefix(1) .. ';;',
    "$BASE$esac",
  }, {
    cursor_line = 2,
    cursor_col = #current_indent(0) + #indent_prefix(1),
  })
end

function M.shell_insert_if()
  insert_shell_block({
    '$BASE$if [ condition ]; then',
    "$BODY$",
    "$BASE$fi",
  }, {
    cursor_line = 2,
  })
end

function M.shell_insert_function()
  local base = current_indent(0)
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
    "$BODY$" .. indent_prefix(1) .. "a)",
    "$BODY$" .. indent_prefix(2) .. ";;",
    "$BODY$" .. indent_prefix(1) .. "b)",
    "$BODY$" .. indent_prefix(2) .. ";;",
    "$BODY$" .. indent_prefix(1) .. "*)",
    "$BODY$" .. indent_prefix(2) .. ";;",
    "$BODY$esac",
    "$BASE$done",
  }, {
    cursor_line = 3,
    cursor_col = #current_indent(0) + #indent_prefix(2),
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

function M.setup()
  local group = vim.api.nvim_create_augroup("user_code_mode_actions", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "go",
    callback = function(event)
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("<localleader>ga", M.go_switch_test_file, "Alternate test/source")
      map("<localleader>ig", M.go_goto_imports, "Go to imports")
      map("<localleader>ir", M.go_organize_imports, "Remove unused imports")
      map("<localleader>tp", M.go_test_package, "Run package tests")
      map("<localleader>tP", M.go_test_all, "Run all package tests")
      map("<localleader>tt", M.go_test_nearest, "Run nearest test")
      map("<localleader>tl", M.go_test_last, "Run last test command")
      map("<localleader>xx", M.go_run_package, "Run package")
      map("<localleader>xg", M.go_generate_file, "Generate for file")
      map("<localleader>xG", M.go_generate_project, "Generate for project")
      map("<localleader>ri", M.go_organize_imports, "Organize imports")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "java",
    callback = function(event)
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("<localleader>ga", M.java_switch_test_file, "Alternate test/source")
      map("<localleader>cc", M.java_build_project, "Build project")
      map("<localleader>ta", M.java_run_all_tests, "Run all tests")
      map("<localleader>tc", M.java_run_class_tests, "Run class tests")
      map("<localleader>tt", M.java_run_nearest_test, "Run nearest test")
      map("<localleader>tl", M.java_run_last_test, "Run last test command")
      map("<localleader>x:", M.java_run_task, "Run build task")
      map("<localleader>ri", M.java_organize_imports, "Organize imports")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "bash", "sh", "zsh" },
    callback = function(event)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("n", "<localleader>i!", M.shell_insert_shebang, "Insert shebang")
      map("n", "<localleader>ic", M.shell_insert_case, "Insert case statement")
      map("n", "<localleader>ii", M.shell_insert_if, "Insert if statement")
      map("n", "<localleader>if", M.shell_insert_function, "Insert function")
      map("n", "<localleader>io", M.shell_insert_for, "Insert for loop")
      map("n", "<localleader>ie", M.shell_insert_indexed_for, "Insert indexed for loop")
      map("n", "<localleader>iw", M.shell_insert_while, "Insert while loop")
      map("n", "<localleader>ir", M.shell_insert_repeat, "Insert repeat loop")
      map("n", "<localleader>is", M.shell_insert_select, "Insert select loop")
      map("n", "<localleader>iu", M.shell_insert_until, "Insert until loop")
      map("n", "<localleader>ig", M.shell_insert_getopts, "Insert getopts loop")
      map("n", "<localleader>\\", M.shell_add_backslashes, "Append backslashes")
      map("x", "<localleader>\\", M.shell_add_backslashes_visual, "Append backslashes")
    end,
  })
end

return M
