local uv = vim.uv or vim.loop

local function path_separator()
  return package.config:sub(1, 1) == "\\" and ";" or ":"
end

local function prepend_path(entry)
  if not entry or entry == "" or not uv.fs_stat(entry) then
    return
  end

  local sep = path_separator()
  local parts = {}

  for value in string.gmatch(vim.env.PATH or "", "([^" .. sep .. "]+)") do
    if value == entry then
      return
    end

    table.insert(parts, value)
  end

  table.insert(parts, 1, entry)
  vim.env.PATH = table.concat(parts, sep)
end

-- Neovim only sees the PATH exported by its parent process. In practice that
-- means headless runs, GUI launches, and wrapper tools may miss mise shims even
-- when an interactive shell has them. Prepend the shims directory here so PATH
-- resolution inside Neovim stays consistent with the rest of the system.
prepend_path(vim.fs.joinpath(vim.env.HOME, ".local", "share", "mise", "shims"))
