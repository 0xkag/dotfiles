-- Headless test for the big-file guard in plugins/ui.lua.
-- Run: nvim/test/run.sh bigfile
--
-- Treesitter attaches to every buffer with a parser, so a multi-megabyte
-- generated file used to hang the editor: measured 2026-09-02 on a 3.2 MB Lua
-- table, 2.2 s to open and 1.7 s for one jump-to-end redraw. snacks.bigfile
-- gives such a buffer the `bigfile` filetype before FileType fires, which is
-- what keeps the treesitter hook and the LSP servers away from it.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/bigfile_spec.lua$", "")
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

-- The snacks entry of the ui spec list.
local snacks
for _, entry in ipairs(require("plugins.ui")) do
  if type(entry) == "table" and entry[1] == "folke/snacks.nvim" then
    snacks = entry
  end
end
check("snacks is configured", snacks ~= nil)
check("bigfile is enabled", snacks and snacks.opts.bigfile and snacks.opts.bigfile.enabled == true, snacks and vim.inspect(snacks.opts.bigfile))

-- The treesitter hook has nothing for a `bigfile` buffer: no parser, so no
-- highlighter, no fold mark and no indentexpr.
local treesitter = require("config.treesitter")
vim.cmd("enew")
vim.bo.filetype = "bigfile"
local buf = vim.api.nvim_get_current_buf()
check("attach declines a bigfile buffer", treesitter.attach(buf) == false)
check("a bigfile buffer is not marked for folds", vim.b[buf].ts_folds == nil, vim.inspect(vim.b[buf].ts_folds))
check("no parser is reported missing for it", vim.deep_equal(treesitter.missing_for_filetype("bigfile"), {}), vim.inspect(treesitter.missing_for_filetype("bigfile")))

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
