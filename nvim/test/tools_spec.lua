-- Headless test for config.tools: the mise-aware executable probe.
-- Run: nvim/test/run.sh tools
--
-- env.lua puts the mise shims dir first on PATH, so a mise-managed tool
-- resolves to a shim and status() verifies it by spawning `mise which`, about
-- 16-18 ms each. deps, lint and the grep setup all probe the same tools, so the
-- result has to be cached for the session, keyed by PATH so pyenv activation
-- (which prepends to PATH) starts over, and :NvimDeps must be able to force a
-- fresh probe.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/tools_spec.lua$", "")
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

-- A fake mise install: a shims dir whose path matches what tools.lua looks
-- for, a `mise` on PATH that logs every call and resolves `which` against a
-- fake install dir, and one plain (non-shim) tool.
local scratch = vim.fn.tempname()
local shims = scratch .. "/.local/share/mise/shims"
local bin = scratch .. "/bin"
local real = scratch .. "/real"
local log = scratch .. "/mise.log"
for _, dir in ipairs({ shims, bin, real }) do
  vim.fn.mkdir(dir, "p")
end
local function script(path, lines)
  vim.fn.writefile(vim.list_extend({ "#!/bin/sh" }, lines), path)
  vim.fn.setfperm(path, "rwxr-xr-x")
end
script(bin .. "/mise", {
  'echo "$@" >> ' .. log,
  '[ "$1" = which ] && [ -x ' .. real .. '/"$2" ] && { echo ' .. real .. '/"$2"; exit 0; }',
  "exit 1",
})
script(shims .. "/managed", { "exit 0" })
script(shims .. "/inactive", { "exit 0" })
script(real .. "/managed", { "exit 0" })
script(bin .. "/plain", { "exit 0" })

local function mise_calls()
  return vim.fn.filereadable(log) == 1 and #vim.fn.readfile(log) or 0
end

local original_path = vim.env.PATH
vim.env.PATH = bin .. ":" .. shims .. ":" .. original_path

local tools = require("config.tools")

-- A live shim resolves through mise once; every later ask is answered from
-- the cache.
do
  local status = tools.status("managed")
  check("shim resolves to the install path", status.available == true and status.path == real .. "/managed", vim.inspect(status, { newline = " " }))
  check("shim records the shim path", status.shim == shims .. "/managed", status.shim)
  check("first probe spawns mise", mise_calls() == 1, mise_calls())
  tools.status("managed")
  check("second probe is cached", mise_calls() == 1, mise_calls())
  check("available() shares the cache", tools.available("managed") == true and mise_calls() == 1, mise_calls())
  check("path() shares the cache", tools.path("managed") == real .. "/managed" and mise_calls() == 1, mise_calls())
end

-- An inactive shim (no install behind it) is cached as unavailable.
do
  local status = tools.status("inactive")
  check("inactive shim is unavailable", status.available == false and status.reason == "inactive mise shim", vim.inspect(status))
  check("inactive shim probed once", mise_calls() == 2, mise_calls())
  tools.status("inactive")
  check("inactive shim is cached", mise_calls() == 2, mise_calls())
end

-- A plain binary and a missing one never involve mise.
do
  local status = tools.status("plain")
  check("plain binary is available", status.available == true and status.path == bin .. "/plain", vim.inspect(status))
  local missing = tools.status("no-such-tool-xyz")
  check("missing binary is unavailable", missing.available == false and missing.reason == "not found", vim.inspect(missing))
  check("neither asked mise", mise_calls() == 2, mise_calls())
  check("missing binary is cached", tools.status("no-such-tool-xyz") == missing)
end

-- A PATH change (pyenv activation prepends to it) starts the cache over.
do
  vim.env.PATH = scratch .. "/extra:" .. vim.env.PATH
  tools.status("managed")
  check("PATH change re-probes", mise_calls() == 3, mise_calls())
  tools.status("managed")
  check("and caches again", mise_calls() == 3, mise_calls())
end

-- invalidate() forces a fresh probe without a PATH change, for :NvimDeps.
do
  tools.invalidate()
  tools.status("managed")
  check("invalidate re-probes", mise_calls() == 4, mise_calls())
end

-- python.lua asks about the pylsp path pylsp_cmd chose, which can be a shim
-- itself; `mise which` takes a tool's name, so the probe passes the basename.
do
  local status = tools.status(shims .. "/managed")
  check("a shim named by its path resolves too", status.available == true and status.path == real .. "/managed", vim.inspect(status, { newline = " " }))
  check("by asking mise for the name", mise_calls() == 5 and vim.fn.readfile(log)[5] == "which managed", vim.inspect(vim.fn.readfile(log)))
end

-- config.tools is the one door to "is this tool here". A raw
-- vim.fn.executable says yes to an inactive mise shim, since the shim is a
-- file on PATH, so a module asking it directly sees a glow or a pyenv the rest
-- of the config knows is missing. options.lua stays plain on purpose: it sets
-- grepprg before lazy loads, and verifying an rg shim there would spawn mise
-- on the startup path.
do
  local offenders = {}
  for _, file in ipairs(vim.fn.globpath(here .. "/lua", "**/*.lua", false, true)) do
    local name = file:sub(#here + 6)
    if name ~= "config/tools.lua" and name ~= "config/options.lua" then
      for _, line in ipairs(vim.fn.readfile(file)) do
        if line:find("vim.fn.executable(", 1, true) then
          table.insert(offenders, name)
          break
        end
      end
    end
  end
  table.sort(offenders)
  check("no module asks vim.fn.executable directly", #offenders == 0, table.concat(offenders, ", "))
end

vim.env.PATH = original_path
vim.fn.delete(scratch, "rf")

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
