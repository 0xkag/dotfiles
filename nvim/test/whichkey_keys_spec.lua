-- Headless test for the which-key key-name overrides in plugins/whichkey.lua.
-- which-key's defaults draw special keys as Nerd Font pictograms, 24 of the 28
-- from the Material Design Icons block that only exists in Nerd Fonts v3, so on
-- an older patched font they render as tofu. The overrides spell them instead.
-- Run: nvim --headless -u NONE -l nvim/test/whichkey_keys_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/whichkey_keys_spec.lua$", "")
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

local keys = require("plugins.whichkey").opts.icons.keys
check("the overrides exist", type(keys) == "table", type(keys))

-- Every key which-key defaults to a glyph, so none is left drawing one.
local wanted = {
  "BS",
  "C",
  "CR",
  "D",
  "Down",
  "Esc",
  "F1",
  "F2",
  "F3",
  "F4",
  "F5",
  "F6",
  "F7",
  "F8",
  "F9",
  "F10",
  "F11",
  "F12",
  "Left",
  "M",
  "Right",
  "S",
  "ScrollWheelDown",
  "ScrollWheelUp",
  "Space",
  "Tab",
  "Up",
}
local missing = {}
for _, key in ipairs(wanted) do
  if not keys[key] then
    table.insert(missing, key)
  end
end
check("every glyph key is overridden", #missing == 0, table.concat(missing, ","))

-- The whole point: nothing here may need a font to draw.
local wide = {}
for key, value in pairs(keys) do
  for i = 1, #value do
    if value:byte(i) > 126 then
      table.insert(wide, key)
      break
    end
  end
end
table.sort(wide)
check("no override needs a patched font", #wide == 0, table.concat(wide, ","))

-- The notation the README already uses.
check("Space reads as SPC", vim.trim(keys.Space) == "SPC", keys.Space)
check("Tab reads as TAB", vim.trim(keys.Tab) == "TAB", keys.Tab)
check("CR reads as RET", vim.trim(keys.CR) == "RET", keys.CR)
check("Esc reads as ESC", vim.trim(keys.Esc) == "ESC", keys.Esc)

-- which-key concatenates the pieces of a mapping with no separator, so a
-- word-style name has to carry its own trailing space and a modifier must not,
-- or "SPC TAB" comes out as "SPCTAB" and "C-g" as "C- g".
for _, key in ipairs({ "BS", "CR", "Down", "Esc", "F1", "Left", "Right", "Space", "Tab", "Up" }) do
  if keys[key]:sub(-1) ~= " " then
    table.insert(wide, key)
  end
end
check("word-style names end in a space", #wide == 0, table.concat(wide, ","))

local joined = {}
for _, key in ipairs({ "C", "D", "M", "S" }) do
  if keys[key]:sub(-1) == " " then
    table.insert(joined, key)
  end
  if keys[key]:sub(-1) ~= "-" then
    table.insert(joined, key .. " (no trailing dash)")
  end
end
check("modifiers end in a dash, not a space", #joined == 0, table.concat(joined, ","))

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
