-- Headless test for config.deps: the once-per-session dependency warnings.
-- Run: nvim/test/run.sh deps
--
-- The first buffer of a filetype gets one warning about its missing tools. The
-- latch used to be set only when something was missing, so with everything
-- installed the check ran again, tools and all, for every buffer of that
-- filetype. A check that found nothing must be remembered too.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/deps_spec.lua$", "")
package.path = here .. "/lua/?.lua;" .. here .. "/lua/?/init.lua;" .. package.path

local failures = {}
local function check(name, cond, detail)
  if cond then
    io.write("ok   - " .. name .. "\n")
  else
    io.write("FAIL - " .. name .. " :: " .. tostring(detail) .. "\n")
    table.insert(failures, name)
  end
end

-- The warnings are skipped without a UI, so pretend there is one.
vim.api.nvim_list_uis = function()
  return { {} }
end
local notifications = {}
vim.notify = function(msg, level)
  table.insert(notifications, { msg = msg, level = level })
end

-- Count the tool probes deps makes, and decide availability per tool.
local tools = require("config.tools")
local probes = 0
local unavailable = {}
tools.status = function(bin)
  probes = probes + 1
  if unavailable[bin] then
    return { available = false, bin = bin, detail = bin, reason = "not found" }
  end
  return { available = true, bin = bin, path = "/fake/bin/" .. bin }
end
local treesitter = require("config.treesitter")
treesitter.missing_for_filetype = function()
  return {}
end

local deps = require("config.deps")

local function buffer_of(filetype)
  vim.cmd("enew")
  local saved = vim.o.eventignore
  vim.o.eventignore = "all"
  vim.bo.filetype = filetype
  vim.o.eventignore = saved
  return vim.api.nvim_get_current_buf()
end

-- Everything installed: the check probes once and is then remembered.
do
  local buf = buffer_of("terraform")
  deps.check_current_buffer(buf)
  local first = probes
  check("a first check probes the filetype's tools", first > 0, first)
  check("a clean check does not warn", #notifications == 0, vim.inspect(notifications))

  deps.check_current_buffer(buf)
  check("a clean check is latched", probes == first, probes - first)
  deps.check_current_buffer(buffer_of("terraform"))
  check("another buffer of the filetype does not probe again", probes == first, probes - first)
end

-- Something missing: one warning, then silence for that filetype.
do
  unavailable["yaml-language-server"] = true
  local buf = buffer_of("yaml")
  deps.check_current_buffer(buf)
  check("a missing tool warns", #notifications == 1 and notifications[1].level == vim.log.levels.WARN, vim.inspect(notifications))
  check("the warning names the tool", notifications[1] and notifications[1].msg:find("yaml-language-server", 1, true) ~= nil, notifications[1] and notifications[1].msg)

  local before = probes
  deps.check_current_buffer(buf)
  check("a missing tool warns only once", #notifications == 1, #notifications)
  check("and is not probed again", probes == before, probes - before)
end

-- :NvimDeps is the explicit audit: it always probes afresh, and starts by
-- dropping the cached tool statuses so a tool installed mid-session shows up.
do
  local invalidated = 0
  tools.invalidate = function()
    invalidated = invalidated + 1
  end
  local before = probes
  deps.command("all")
  check("NvimDeps invalidates the tool cache", invalidated == 1, invalidated)
  check("NvimDeps probes", probes > before, probes - before)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
