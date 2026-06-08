-- Headless test harness for config.completion mode state machine.
-- Run: nvim --headless -u NONE -l nvim/test/completion_spec.lua
--
-- Only the pure mode logic is under test (valid_mode, cycle_mode, set_mode,
-- toggle_buffer). configure_cmp() needs the cmp plugin and is exercised
-- interactively, not here; apply() is a no-op when cmp is absent.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/completion_spec.lua$", "")
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

-- Silence the INFO/WARN notifications the mode setters emit so spec output is
-- just the ok/FAIL lines.
vim.notify = function() end

local completion = require("config.completion")

-- valid_mode(): exactly the three known modes.
check("valid_mode quiet", completion.valid_mode("quiet") == true)
check("valid_mode manual", completion.valid_mode("manual") == true)
check("valid_mode full", completion.valid_mode("full") == true)
check("valid_mode rejects junk", completion.valid_mode("loud") == false, completion.valid_mode("loud"))
check("valid_mode rejects nil", completion.valid_mode(nil) == false)

-- set_mode(): valid modes stick; invalid ones leave state unchanged.
completion.set_mode("manual")
check("set_mode manual sticks", completion.state.mode == "manual", completion.state.mode)
completion.set_mode("bogus")
check("set_mode ignores invalid", completion.state.mode == "manual", completion.state.mode)

-- cycle_mode(false): two-way quiet <-> manual, never reaches full.
completion.set_mode("quiet")
completion.cycle_mode(false)
check("cycle(false) quiet -> manual", completion.state.mode == "manual", completion.state.mode)
completion.cycle_mode(false)
check("cycle(false) manual -> quiet", completion.state.mode == "quiet", completion.state.mode)
-- From a mode outside the 2-cycle (full), cycle_mode(false) treats the current
-- mode as index 1 and advances to the second entry (manual).
completion.set_mode("full")
completion.cycle_mode(false)
check("cycle(false) from full -> manual", completion.state.mode == "manual", completion.state.mode)

-- cycle_mode(true): three-way quiet -> manual -> full -> quiet.
completion.set_mode("quiet")
completion.cycle_mode(true)
check("cycle(true) quiet -> manual", completion.state.mode == "manual", completion.state.mode)
completion.cycle_mode(true)
check("cycle(true) manual -> full", completion.state.mode == "full", completion.state.mode)
completion.cycle_mode(true)
check("cycle(true) full -> quiet", completion.state.mode == "quiet", completion.state.mode)

-- toggle_buffer(): flips the per-buffer cmp_disabled flag.
local buf = vim.api.nvim_get_current_buf()
vim.b[buf].cmp_disabled = nil
completion.toggle_buffer()
check("toggle_buffer disables", vim.b[buf].cmp_disabled == true, vim.b[buf].cmp_disabled)
completion.toggle_buffer()
check("toggle_buffer re-enables", vim.b[buf].cmp_disabled == false, vim.b[buf].cmp_disabled)

-- set_delay(): seconds -> ms; rejects negatives/non-numbers.
completion.set_delay(1.5)
check("set_delay 1.5s -> 1500ms", completion.state.delay_ms == 1500, completion.state.delay_ms)
completion.set_delay(-1)
check("set_delay rejects negative", completion.state.delay_ms == 1500, completion.state.delay_ms)
completion.set_delay("notanumber")
check("set_delay rejects non-number", completion.state.delay_ms == 1500, completion.state.delay_ms)

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
