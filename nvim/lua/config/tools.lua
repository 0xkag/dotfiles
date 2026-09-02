local M = {}

local uv = vim.uv or vim.loop

local function is_mise_shim(path)
  return path:find("/.local/share/mise/shims/", 1, true) ~= nil
end

-- Probe results for the session, keyed by the PATH they were resolved under.
-- A mise-managed tool resolves to a shim, and verifying a shim spawns
-- `mise which` (16-18 ms of mise loading its config, not the exec); deps, lint
-- and the grep setup all ask about the same tools, so the answer is kept. A
-- PATH change starts over, since pyenv activation prepends a venv's bin and
-- can change what a name resolves to.
local cache = {}
local cache_path = nil

local function cache_for_path()
  if vim.env.PATH ~= cache_path then
    cache = {}
    cache_path = vim.env.PATH
  end
  return cache
end

-- Drop every cached probe, so the next ask resolves afresh. :NvimDeps calls
-- this first: an explicit audit must see a tool installed mid-session.
function M.invalidate()
  cache = {}
  cache_path = nil
end

local function probe(bin)
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

function M.status(bin)
  local entries = cache_for_path()
  local status = entries[bin]
  if status == nil then
    status = probe(bin)
    entries[bin] = status
  end
  return status
end

function M.available(bin)
  return M.status(bin).available
end

function M.path(bin)
  return M.status(bin).path
end

return M
