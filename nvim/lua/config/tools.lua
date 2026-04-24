local M = {}

local uv = vim.uv or vim.loop

local function is_mise_shim(path)
  return path:find("/.local/share/mise/shims/", 1, true) ~= nil
end

function M.status(bin)
  local path = vim.fn.exepath(bin)
  if path == "" then
    return {
      available = false,
      bin = bin,
      detail = bin,
      reason = "not found",
    }
  end

  if is_mise_shim(path) then
    if vim.fn.executable("mise") ~= 1 then
      return {
        available = false,
        bin = bin,
        detail = bin .. " (inactive mise shim)",
        reason = "inactive mise shim",
      }
    end

    local result = vim.system({ "mise", "which", bin }, { text = true }):wait()
    if result.code ~= 0 then
      return {
        available = false,
        bin = bin,
        detail = bin .. " (inactive mise shim)",
        reason = "inactive mise shim",
      }
    end

    local resolved = vim.trim(result.stdout or "")
    if resolved == "" or not uv.fs_stat(resolved) then
      return {
        available = false,
        bin = bin,
        detail = bin .. " (inactive mise shim)",
        reason = "inactive mise shim",
      }
    end

    return {
      available = true,
      bin = bin,
      path = resolved,
      shim = path,
    }
  end

  return {
    available = true,
    bin = bin,
    path = path,
  }
end

function M.available(bin)
  return M.status(bin).available
end

function M.path(bin)
  return M.status(bin).path
end

return M
