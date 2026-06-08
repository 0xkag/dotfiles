-- Java code-mode helpers: build-tool detection, test running, imports.
local M = {}

local shared = require("config.code_mode.shared")
local tools = require("config.tools")
local util = require("config.util")

-- Fully-qualified-name helpers below are pure given buffer contents, so they
-- are unit-tested in test/code_mode_spec.lua.

function M.java_package_name(bufnr)
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

function M.java_class_name(bufnr)
  local file = shared.current_file(bufnr)
  if not file then
    return nil
  end

  return vim.fn.fnamemodify(file, ":t:r")
end

function M.java_test_class_name(bufnr)
  local class_name = M.java_class_name(bufnr)
  if not class_name then
    return nil
  end

  if class_name:match("Test$") then
    return class_name
  end

  return class_name .. "Test"
end

function M.java_test_method_name(bufnr)
  local pending_test_annotation = false

  return shared.nearest_matching_line(bufnr or 0, function(line)
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

function M.java_build_tool(root)
  if not root then
    return nil
  end

  if shared.file_exists(vim.fs.joinpath(root, "mvnw")) then
    return { name = "maven", root = root, shell = "./mvnw" }
  end

  if shared.file_exists(vim.fs.joinpath(root, "pom.xml")) then
    if not tools.available("mvn") then
      vim.notify("Install maven or provide a project-local mvnw wrapper.", vim.log.levels.WARN)
      return nil
    end

    return { name = "maven", root = root, shell = "mvn" }
  end

  if shared.file_exists(vim.fs.joinpath(root, "gradlew")) then
    return { name = "gradle", root = root, shell = "./gradlew" }
  end

  if shared.file_exists(vim.fs.joinpath(root, "build.gradle")) or shared.file_exists(vim.fs.joinpath(root, "build.gradle.kts")) then
    if not tools.available("gradle") then
      vim.notify("Install gradle or provide a project-local gradlew wrapper.", vim.log.levels.WARN)
      return nil
    end

    return { name = "gradle", root = root, shell = "gradle" }
  end

  vim.notify("No Maven or Gradle build found in this project.", vim.log.levels.INFO)
  return nil
end

function M.java_fqcn(bufnr, use_test_class)
  local class_name = use_test_class and M.java_test_class_name(bufnr) or M.java_class_name(bufnr)
  if not class_name then
    return nil
  end

  local package_name = M.java_package_name(bufnr)
  if package_name and package_name ~= "" then
    return package_name .. "." .. class_name
  end

  return class_name
end

function M.java_switch_test_file()
  local file = shared.current_file(0)
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

  shared.edit_if_exists(target)
end

function M.java_build_project()
  local tool = M.java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  local command = tool.name == "maven" and (tool.shell .. " -DskipTests compile") or (tool.shell .. " classes")

  shared.run_command("java build", command, {
    cwd = tool.root,
    last_key = "java_build",
  })
end

function M.java_run_all_tests()
  local tool = M.java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  shared.run_command("java test", tool.shell .. " test", {
    cwd = tool.root,
    last_key = "java_test",
  })
end

function M.java_run_class_tests()
  local tool = M.java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  local test_class = M.java_test_class_name(0)
  if not test_class then
    vim.notify("Unable to determine the Java test class.", vim.log.levels.INFO)
    return
  end

  local command
  if tool.name == "maven" then
    command = tool.shell .. " -Dtest=" .. shared.shellescape(test_class) .. " test"
  else
    command = tool.shell .. " test --tests " .. shared.shellescape(M.java_fqcn(0, true))
  end

  shared.run_command("java test", command, {
    cwd = tool.root,
    last_key = "java_test",
  })
end

function M.java_run_nearest_test()
  local tool = M.java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  local test_class = M.java_test_class_name(0)
  local method = M.java_test_method_name(0)
  if not test_class or not method then
    vim.notify("No Java test method found near the cursor.", vim.log.levels.INFO)
    return
  end

  local command
  if tool.name == "maven" then
    command = tool.shell .. " -Dtest=" .. shared.shellescape(test_class .. "#" .. method) .. " test"
  else
    command = tool.shell .. " test --tests " .. shared.shellescape(M.java_fqcn(0, true) .. "." .. method)
  end

  shared.run_command("java test", command, {
    cwd = tool.root,
    last_key = "java_test",
  })
end

function M.java_run_last_test()
  shared.rerun_last("java_test")
end

function M.java_run_task()
  local tool = M.java_build_tool(util.project_root(0))
  if not tool then
    return
  end

  vim.ui.input({
    prompt = tool.name == "maven" and "Maven task > " or "Gradle task > ",
  }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end

    shared.run_command("java task", tool.shell .. " " .. input, {
      cwd = tool.root,
      last_key = "java_task",
    })
  end)
end

function M.java_organize_imports()
  shared.organize_imports()
end

return M
