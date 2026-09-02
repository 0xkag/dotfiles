-- Headless test for config.deps and config.health: the once-per-session
-- dependency warnings and the :checkhealth report that replaced the startup
-- sweep.
-- Run: nvim/test/run.sh deps
--
-- The first buffer of a filetype gets one warning about its missing tools. The
-- latch used to be set only when something was missing, so with everything
-- installed the check ran again, tools and all, for every buffer of that
-- filetype. A check that found nothing must be remembered too.
--
-- The full audit used to run 500 ms after VimEnter and block for 172 ms with a
-- cold tool cache (28 features, the mise-managed tools at ~17 ms each). It is
-- now `:checkhealth config`, on demand, and the one feature table also covers
-- the servers lsp.lua configures and the linters config.linters runs, which
-- three hand-kept lists used to disagree about.
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

-- An explicit check of the current buffer bypasses the latch and says so when
-- everything is there, since the user asked.
do
  local buf = buffer_of("terraform")
  notifications = {}
  local before = probes
  deps.check_current_buffer(buf, { force = true })
  check("a forced check probes again", probes > before, probes - before)
  check("a forced clean check reports success", #notifications == 1 and notifications[1].level == vim.log.levels.INFO, vim.inspect(notifications))
end

-- The startup sweep and :NvimDeps are gone; the audit is :checkhealth config.
do
  check(":NvimDeps no longer exists", vim.fn.exists(":NvimDeps") == 0, vim.fn.exists(":NvimDeps"))
  local ok, vimenter = pcall(vim.api.nvim_get_autocmds, { group = "user_deps", event = "VimEnter" })
  check("deps registers no VimEnter sweep", ok and #vimenter == 0, ok and #vimenter or vimenter)
  local filetype = ok and vim.api.nvim_get_autocmds({ group = "user_deps", event = "FileType" }) or {}
  check("the once-per-filetype warning stays", #filetype > 0, #filetype)
end

-- The health report: probes afresh, one section per area, one line per
-- feature, missing tools as warnings that name the tool.
do
  local report = { starts = {}, ok = {}, warn = {}, error = {} }
  vim.health = {
    start = function(name)
      table.insert(report.starts, name)
    end,
    ok = function(msg)
      table.insert(report.ok, msg)
    end,
    warn = function(msg, advice)
      table.insert(report.warn, { msg = msg, advice = advice })
    end,
    error = function(msg, advice)
      table.insert(report.error, { msg = msg, advice = advice })
    end,
    info = function() end,
  }
  local invalidated = 0
  tools.invalidate = function()
    invalidated = invalidated + 1
  end
  unavailable["terraform-ls"] = true

  local before = probes
  require("config.health").check()
  check("checkhealth invalidates the tool cache first", invalidated == 1, invalidated)
  check("checkhealth probes", probes > before, probes - before)
  check("checkhealth has sections", #report.starts >= 2, vim.inspect(report.starts))
  check("nothing is an error", #report.error == 0, vim.inspect(report.error))

  local function find(list, pattern)
    for _, item in ipairs(list) do
      local msg = type(item) == "table" and item.msg or item
      if msg:find(pattern) then
        return msg
      end
    end
    return nil
  end
  check("an available tool is ok, naming the binary", find(report.ok, "^Git integration: git") ~= nil, vim.inspect(report.ok))
  check("a missing tool is a warning naming it", find(report.warn, "^Terraform LSP: missing terraform%-ls") ~= nil, vim.inspect(report.warn))
  check("the earlier missing server is still reported", find(report.warn, "yaml%-language%-server") ~= nil, vim.inspect(report.warn))
  check("the per-buffer parser check is not in the report", find(report.ok, "^Treesitter parser:") == nil and find(report.warn, "^Treesitter parser:") == nil)
  check("configured parsers are", find(report.ok, "^Treesitter parsers") ~= nil, vim.inspect(report.ok))

  -- The servers lsp.lua configures that no list checked, and the linters as
  -- config.linters actually runs them (mypy first; ruff is the LSP's job).
  for _, bin in ipairs({ "ansible%-language%-server", "vscode%-css%-language%-server", "docker%-langserver", "taplo" }) do
    check("checkhealth covers " .. bin:gsub("%%", ""), find(report.ok, bin) ~= nil, bin)
  end
  check("python linting is reported as nvim-lint runs it", find(report.ok, "^Python linting: mypy") ~= nil, find(report.ok, "^Python linting"))
  check("ruff is not advertised as a linter", find(report.ok, "^Python linting.*ruff") == nil, find(report.ok, "^Python linting"))
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
