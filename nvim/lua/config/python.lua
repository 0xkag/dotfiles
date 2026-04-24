local M = {}

local uv = vim.uv or vim.loop

local cached_prefixes = {}
local cached_modules = {}
local active_prefix = nil

local function start_dir_for_buffer(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    return vim.fs.dirname(name)
  end

  return uv.cwd()
end

local function version_file_for_dir(start_dir)
  if not start_dir or start_dir == "" then
    return nil
  end

  return vim.fs.find(".python-version", {
    path = start_dir,
    upward = true,
    stop = vim.env.HOME,
  })[1]
end

local function path_separator()
  return package.config:sub(1, 1) == "\\" and ";" or ":"
end

local function split_path(path)
  local parts = {}
  local sep = path_separator()

  for entry in string.gmatch(path or "", "([^" .. sep .. "]+)") do
    table.insert(parts, entry)
  end

  return parts
end

local function join_path(parts)
  return table.concat(parts, path_separator())
end

local function prepend_path(entry)
  local parts = split_path(vim.env.PATH)
  local filtered = {}

  for _, part in ipairs(parts) do
    if part ~= entry then
      table.insert(filtered, part)
    end
  end

  table.insert(filtered, 1, entry)
  vim.env.PATH = join_path(filtered)
end

local function remove_path(entry)
  local parts = split_path(vim.env.PATH)
  local filtered = {}

  for _, part in ipairs(parts) do
    if part ~= entry then
      table.insert(filtered, part)
    end
  end

  vim.env.PATH = join_path(filtered)
end

local function clear_active_prefix()
  if not active_prefix then
    return
  end

  remove_path(vim.fs.joinpath(active_prefix, "bin"))
  vim.env.VIRTUAL_ENV = nil
  active_prefix = nil
end

local function pyenv_prefix(version)
  if cached_prefixes[version] ~= nil then
    return cached_prefixes[version] or nil
  end

  local result = vim.system({ "pyenv", "prefix", version }, { text = true }):wait()
  if result.code ~= 0 then
    cached_prefixes[version] = false
    return nil
  end

  local prefix = vim.trim(result.stdout or "")
  if prefix == "" then
    cached_prefixes[version] = false
    return nil
  end

  cached_prefixes[version] = prefix
  return prefix
end

local function version_from_file(version_file)
  if not version_file or vim.fn.filereadable(version_file) ~= 1 then
    return nil
  end

  for _, line in ipairs(vim.fn.readfile(version_file)) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" then
      return trimmed
    end
  end

  return nil
end

local function prefix_for_dir(start_dir)
  if vim.fn.executable("pyenv") ~= 1 then
    return nil
  end

  local version = version_from_file(version_file_for_dir(start_dir))
  if not version or version == "system" then
    return nil
  end

  return pyenv_prefix(version)
end

function M.prefix(bufnr)
  return prefix_for_dir(start_dir_for_buffer(bufnr or 0))
end

function M.active_prefix()
  return active_prefix
end

function M.python_bin(target)
  local prefix = nil

  if type(target) == "number" then
    prefix = M.prefix(target)
  elseif type(target) == "string" and target ~= "" then
    prefix = prefix_for_dir(target)
  else
    prefix = active_prefix
  end

  if prefix then
    local python = vim.fs.joinpath(prefix, "bin", "python")
    if uv.fs_stat(python) then
      return python
    end
  end

  local python = vim.fn.exepath("python3")
  if python ~= "" then
    return python
  end

  python = vim.fn.exepath("python")
  if python ~= "" then
    return python
  end

  return nil
end

function M.module_status(module, target)
  local python = M.python_bin(target)
  if not python then
    return {
      available = false,
      detail = module .. " (no python interpreter)",
      module = module,
    }
  end

  local cache_key = python .. "::" .. module
  if cached_modules[cache_key] then
    return vim.deepcopy(cached_modules[cache_key])
  end

  local result = vim.system({ python, "-c", "import " .. module }, { text = true }):wait()
  local status

  if result.code == 0 then
    status = {
      available = true,
      module = module,
      python = python,
    }
  else
    status = {
      available = false,
      detail = module .. " (missing in " .. python .. ")",
      module = module,
      python = python,
    }
  end

  cached_modules[cache_key] = status
  return vim.deepcopy(status)
end

function M.module_available(module, target)
  return M.module_status(module, target).available
end

function M.pyright_settings(root_dir)
  local settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "workspace",
        exclude = {
          "**/.mypy_cache",
          "**/.pytest_cache",
          "**/veritas-config/**",
        },
        useLibraryCodeForTypes = true,
      },
    },
  }

  local prefix = nil
  if type(root_dir) == "string" and root_dir ~= "" then
    prefix = prefix_for_dir(root_dir)
  else
    prefix = active_prefix
  end

  local python = M.python_bin(root_dir)
  if python then
    settings.python.pythonPath = python
  end

  if prefix then
    settings.python.venvPath = vim.fs.dirname(prefix)
    settings.python.venv = vim.fs.basename(prefix)
  end

  return settings
end

function M.show_info(bufnr)
  bufnr = bufnr or 0

  local start_dir = start_dir_for_buffer(bufnr)
  local version_file = version_file_for_dir(start_dir)
  local prefix = M.prefix(bufnr) or active_prefix
  local python = M.python_bin(bufnr) or "<none>"

  vim.notify(table.concat({
    "version file: " .. (version_file or "<none>"),
    "prefix: " .. (prefix or "<none>"),
    "python: " .. python,
    "VIRTUAL_ENV: " .. (vim.env.VIRTUAL_ENV or "<none>"),
  }, "\n"), vim.log.levels.INFO, {
    title = "Python Env",
  })
end

function M.activate(bufnr)
  local prefix = M.prefix(bufnr)
  if not prefix then
    clear_active_prefix()
    return
  end

  if prefix == active_prefix then
    return
  end

  local bin = vim.fs.joinpath(prefix, "bin")
  if not uv.fs_stat(bin) then
    clear_active_prefix()
    return
  end

  clear_active_prefix()
  prepend_path(bin)
  vim.env.VIRTUAL_ENV = prefix
  active_prefix = prefix
end

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
  pattern = { "*.py", "*.pyi" },
  callback = function(event)
    M.activate(event.buf)
  end,
})

vim.api.nvim_create_user_command("PyenvInfo", function()
  M.show_info(0)
end, {
  desc = "Show Python environment for current buffer",
})

return M
