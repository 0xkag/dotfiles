local M = {}

local uv = vim.uv or vim.loop
local util = require("config.util")

local state_file = vim.fs.joinpath(vim.fn.stdpath("state"), "projects.txt")
local max_projects = 50

local function normalize(path)
  if not path or path == "" then
    return nil
  end

  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function is_dir(path)
  local stat = path and uv.fs_stat(path) or nil
  return stat and stat.type == "directory"
end

local function display_path(path)
  return vim.fn.fnamemodify(path, ":~")
end

local function ensure_state_dir()
  vim.fn.mkdir(vim.fs.dirname(state_file), "p")
end

local function read_projects()
  local projects = {}
  local file = io.open(state_file, "r")
  if not file then
    return projects
  end

  for line in file:lines() do
    local path = normalize(vim.trim(line))
    if is_dir(path) then
      table.insert(projects, path)
    end
  end

  file:close()
  return projects
end

local function write_projects(projects)
  ensure_state_dir()

  local file = assert(io.open(state_file, "w"))
  for _, path in ipairs(projects) do
    file:write(path, "\n")
  end
  file:close()
end

local function dedupe(projects)
  local seen = {}
  local results = {}

  for _, path in ipairs(projects) do
    path = normalize(path)
    if is_dir(path) and not seen[path] then
      seen[path] = true
      table.insert(results, path)
    end

    if #results >= max_projects then
      break
    end
  end

  return results
end

local function listed_file_buffers()
  local count = 0

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr)
      and vim.bo[bufnr].buflisted
      and vim.bo[bufnr].buftype == ""
      and vim.api.nvim_buf_get_name(bufnr) ~= "" then
      count = count + 1
    end
  end

  return count
end

local function modified_file_buffers()
  local modified = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr)
      and vim.bo[bufnr].modified
      and vim.bo[bufnr].buftype == ""
      and vim.api.nvim_buf_get_name(bufnr) ~= "" then
      table.insert(modified, display_path(vim.api.nvim_buf_get_name(bufnr)))
    end
  end

  return modified
end

local function current_from_buffer(bufnr)
  bufnr = bufnr or 0

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    local root = util.find_root(name)
    if root then
      return normalize(root)
    end
  end

  local cwd_root = util.find_root(util.cwd())
  if cwd_root then
    return normalize(cwd_root)
  end

  return nil
end

local function save_current_session()
  local ok, persistence = pcall(require, "persistence")
  if ok and persistence.active() then
    persistence.save()
  end
end

local function load_project_session()
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    return
  end

  if not persistence.active() then
    persistence.start()
  end

  persistence.load()
end

function M.list()
  local projects = dedupe(read_projects())
  write_projects(projects)
  return projects
end

function M.current(bufnr)
  return current_from_buffer(bufnr)
end

function M.add(path, opts)
  opts = opts or {}
  path = normalize(path) or current_from_buffer(0) or normalize(util.cwd())

  if not is_dir(path) then
    if not opts.silent then
      vim.notify("Project directory not found.", vim.log.levels.WARN)
    end
    return nil
  end

  local projects = { path }
  vim.list_extend(projects, read_projects())
  projects = dedupe(projects)
  write_projects(projects)

  if not opts.silent then
    vim.notify("Added project: " .. display_path(path), vim.log.levels.INFO)
  end

  return path
end

function M.remove(path, opts)
  opts = opts or {}
  path = normalize(path) or current_from_buffer(0) or normalize(util.cwd())
  if not path then
    return false
  end

  local projects = {}
  local removed = false

  for _, project in ipairs(read_projects()) do
    if normalize(project) ~= path then
      table.insert(projects, project)
    else
      removed = true
    end
  end

  write_projects(dedupe(projects))

  if removed and not opts.silent then
    vim.notify("Removed project: " .. display_path(path), vim.log.levels.INFO)
  elseif not removed and not opts.silent then
    vim.notify("Project was not in recent history.", vim.log.levels.INFO)
  end

  return removed
end

function M.track(bufnr)
  local project = current_from_buffer(bufnr)
  if project then
    M.add(project, { silent = true })
  end
end

function M.switch(path)
  path = normalize(path)
  if not is_dir(path) then
    vim.notify("Project directory not found.", vim.log.levels.WARN)
    return
  end

  local dirty = modified_file_buffers()
  if #dirty > 0 then
    vim.notify("Save or discard modified buffers before switching projects.", vim.log.levels.WARN)
    return
  end

  save_current_session()
  M.add(path, { silent = true })

  if normalize(util.cwd()) ~= path then
    vim.cmd("silent! %bwipeout!")
    vim.fn.chdir(path)
  end

  load_project_session()

  if listed_file_buffers() > 0 or #vim.api.nvim_list_uis() == 0 then
    vim.notify("Switched to project: " .. display_path(path), vim.log.levels.INFO)
    return
  end

  vim.schedule(function()
    util.find_files({
      cwd = path,
      title = "Project Files",
    })
  end)
end

function M.pick()
  local projects = M.list()
  if #projects == 0 then
    vim.notify("No recent projects recorded yet.", vim.log.levels.INFO)
    return
  end

  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.ui.select(projects, {
      prompt = "Projects",
      format_item = display_path,
    }, function(item)
      if item then
        M.switch(item)
      end
    end)
    return
  end

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")

  local function entry_maker(path)
    return {
      value = path,
      display = display_path(path),
      ordinal = display_path(path),
    }
  end

  local function refresh(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    picker:refresh(finders.new_table({
      results = M.list(),
      entry_maker = entry_maker,
    }), { reset_prompt = true })
  end

  pickers.new({}, {
    prompt_title = "Projects",
    finder = finders.new_table({
      results = projects,
      entry_maker = entry_maker,
    }),
    previewer = false,
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          M.switch(selection.value)
        end
      end)

      local function remove_selection()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end

        M.remove(selection.value, { silent = true })
        refresh(prompt_bufnr)
      end

      map("i", "<C-d>", remove_selection)
      map("n", "dd", remove_selection)
      return true
    end,
  }):find()
end

function M.setup()
  local group = vim.api.nvim_create_augroup("nvim-projects", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "VimEnter" }, {
    group = group,
    callback = function(event)
      if event.buf ~= 0 and vim.bo[event.buf].buftype ~= "" then
        return
      end

      M.track(event.buf)
    end,
  })

  vim.api.nvim_create_user_command("ProjectSwitch", function(command)
    if command.args ~= "" then
      M.switch(command.args)
      return
    end

    M.pick()
  end, {
    complete = "dir",
    desc = "Switch projects",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ProjectAdd", function(command)
    M.add(command.args ~= "" and command.args or nil)
  end, {
    complete = "dir",
    desc = "Add a project to recent history",
    nargs = "?",
  })

  vim.api.nvim_create_user_command("ProjectRemove", function(command)
    M.remove(command.args ~= "" and command.args or nil)
  end, {
    complete = "dir",
    desc = "Remove a project from recent history",
    nargs = "?",
  })
end

return M
