-- Headless test harness for config.diagnostic_float: toggle state and that
-- setup registers a single CursorHold autocmd idempotently. Run:
--   nvim --headless -u NONE -l nvim/test/diagnostic_float_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/diagnostic_float_spec.lua$", "")
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

local df = require("config.diagnostic_float")

-- Enabled by default; toggle flips and is reversible.
do
  check("enabled by default", df.is_enabled() == true)
  df.toggle()
  check("toggle disables", df.is_enabled() == false)
  df.toggle()
  check("toggle re-enables", df.is_enabled() == true)
end

-- setup() registers exactly one CursorHold autocmd and is idempotent.
do
  df.setup()
  local function count()
    return #vim.api.nvim_get_autocmds({ group = "diagnostic_float", event = "CursorHold" })
  end
  check("CursorHold registered", count() == 1, count())
  df.setup()
  check("setup idempotent", count() == 1, count())
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
