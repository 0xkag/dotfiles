-- Headless test harness for config.lsp_semantic_guard pure helpers. Run:
--   nvim --headless -u NONE -l nvim/test/lsp_semantic_guard_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/lsp_semantic_guard_spec.lua$", "")
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

local function eq(a, b)
  return vim.deep_equal(a, b)
end

local guard = require("config.lsp_semantic_guard")

-- clamp_data(): the deltaStart (2nd) and length (3rd) fields are clamped when
-- they exceed max_len; other fields are untouched.
do
  -- {deltaLine, deltaStart, length, type, modifiers}
  local data = { 0, 0, 5, 1, 0, 1, 2, 99, 3, 0 }
  guard.clamp_data(data, 10)
  check("clamp leaves in-range length", data[3] == 5, data[3])
  check("clamp caps oversized length", data[8] == 10, data[8])
  check("clamp leaves non-length fields", eq(data, { 0, 0, 5, 1, 0, 1, 2, 10, 3, 0 }), vim.inspect(data))
end

-- The observed terraform-ls bug: deltaStart is a negative delta wrapped to a
-- huge uint32. It must be clamped, length left alone.
do
  local data = { 0, 4294967253, 3, 8, 0 }
  guard.clamp_data(data, 80)
  check("clamp caps wrapped deltaStart", data[2] == 80, data[2])
  check("clamp leaves valid length with bad deltaStart", data[3] == 3, data[3])
end

-- In-range deltaStart is untouched.
do
  local data = { 1, 40, 5, 1, 0 }
  guard.clamp_data(data, 80)
  check("clamp keeps in-range deltaStart", data[2] == 40, data[2])
end

-- Boundary: length exactly at max_len is not changed.
do
  local data = { 0, 0, 10, 1, 0 }
  guard.clamp_data(data, 10)
  check("clamp keeps length == max", data[3] == 10, data[3])
end

-- Robustness: non-table data and non-number length are passed through.
do
  check("clamp nil data", guard.clamp_data(nil, 10) == nil)
  local data = { 0, 0, "x", 1, 0 }
  guard.clamp_data(data, 10)
  check("clamp ignores non-number length", data[3] == "x", tostring(data[3]))
end

-- max_line_length(): longest line in a real scratch buffer, in bytes.
do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab", "abcdef", "abc" })
  check("max_line_length picks longest", guard.max_line_length(buf) == 6, guard.max_line_length(buf))
  vim.api.nvim_buf_delete(buf, { force = true })

  check("max_line_length invalid buf -> 0", guard.max_line_length(123456) == 0)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
