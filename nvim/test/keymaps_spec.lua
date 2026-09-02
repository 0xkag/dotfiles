-- Headless test for config.keymaps: the `gr` prefix.
-- Run: nvim/test/run.sh keymaps
--
-- Neovim 0.11 ships grn / grr / gri / gra / grt as default LSP mappings. This
-- config maps `gr` itself (references, Spacemacs muscle memory), and with both
-- present every `gr` waits the full timeoutlen for a possible third key. The
-- defaults are deleted so `gr` fires at once; `gO` has no such clash and stays.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/keymaps_spec.lua$", "")
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

local function mapped(lhs, mode)
  return vim.fn.maparg(lhs, mode or "n") ~= ""
end

-- The defaults are there before the config runs, or this spec proves nothing.
check("grn is a default before the config", mapped("grn"))
check("gra is a default in visual mode before the config", mapped("gra", "x"))

require("config.keymaps")

for _, lhs in ipairs({ "grn", "grr", "gri", "gra", "grt" }) do
  check(lhs .. " default is gone", not mapped(lhs), vim.fn.maparg(lhs, "n"))
end
check("gra default is gone in visual mode", not mapped("gra", "x"), vim.fn.maparg("gra", "x"))
check("gO default stays", mapped("gO"))
check("gr is mapped", mapped("gr"), vim.fn.maparg("gr", "n"))
check("gd is mapped", mapped("gd"), vim.fn.maparg("gd", "n"))

-- Maps that restate Neovim's own defaults are not repeated: `Y` is `y$` since
-- 0.6, and `[d` / `]d` jump diagnostics since 0.11 (with the same
-- vim.diagnostic.jump call). `K` is not one of them: the config's hover adds a
-- rounded border and its own close events, so it stays. The diagnostic jumps
-- live in lsp.lua's plugin config, which no spec loads, so that file is read.
check("Y keeps Neovim's default mapping", vim.fn.maparg("Y", "n", false, true).desc == ":help Y-default", vim.inspect(vim.fn.maparg("Y", "n", false, true)))
local lsp_source = table.concat(vim.fn.readfile(here .. "/lua/plugins/lsp.lua"), "\n")
check("lsp.lua does not remap [d", not lsp_source:find('"[d"', 1, true))
check("lsp.lua does not remap ]d", not lsp_source:find('"]d"', 1, true))
check("lsp.lua keeps its own K hover", lsp_source:find('map("n", "K", hover', 1, true) ~= nil)

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
