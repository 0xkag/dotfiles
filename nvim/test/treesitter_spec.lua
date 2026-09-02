-- Headless test for config.treesitter: which parser a filetype needs and
-- which configured parsers are missing.
-- Run: nvim/test/run.sh treesitter
--
-- The filetype-to-language mapping is Neovim's own (vim.treesitter.language
-- .get_lang, extended by nvim-treesitter's registrations at runtime). It never
-- returns nil, so a filetype nothing registered maps to itself; a parser is
-- only reported missing when it is one this config lists, otherwise `:NvimDeps
-- current` in a tftpl buffer would ask for a `tftpl` parser that does not
-- exist.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/treesitter_spec.lua$", "")
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

local treesitter = require("config.treesitter")

-- parser_for_filetype(): Neovim's mapping, nil for no filetype.
do
  check("lua maps to lua", treesitter.parser_for_filetype("lua") == "lua", treesitter.parser_for_filetype("lua"))
  check("help maps to vimdoc", treesitter.parser_for_filetype("help") == "vimdoc", treesitter.parser_for_filetype("help"))
  check("an unregistered filetype maps to itself", treesitter.parser_for_filetype("tftpl") == "tftpl", treesitter.parser_for_filetype("tftpl"))
  check("empty filetype is nil", treesitter.parser_for_filetype("") == nil)
  check("nil filetype is nil", treesitter.parser_for_filetype(nil) == nil)
end

-- missing_for_filetype(): only parsers this config lists can be missing.
do
  check("a bundled parser is not missing", vim.deep_equal(treesitter.missing_for_filetype("lua"), {}), vim.inspect(treesitter.missing_for_filetype("lua")))
  check("an unlisted language is not missing", vim.deep_equal(treesitter.missing_for_filetype("tftpl"), {}), vim.inspect(treesitter.missing_for_filetype("tftpl")))
  check("no filetype is not missing", vim.deep_equal(treesitter.missing_for_filetype(""), {}))

  local saved = treesitter.parsers
  treesitter.parsers = { "lua", "zzz_not_a_parser" }
  check(
    "a listed parser that is not installed is missing",
    vim.deep_equal(treesitter.missing_for_filetype("zzz_not_a_parser"), { "zzz_not_a_parser" }),
    vim.inspect(treesitter.missing_for_filetype("zzz_not_a_parser"))
  )
  check(
    "missing_configured reports it too",
    vim.deep_equal(treesitter.missing_configured(), { "zzz_not_a_parser" }),
    vim.inspect(treesitter.missing_configured())
  )
  treesitter.parsers = saved
end

-- The configured list is sorted, so a new entry has one obvious place to go.
do
  local sorted = vim.deepcopy(treesitter.parsers)
  table.sort(sorted)
  check("parsers list is sorted", vim.deep_equal(sorted, treesitter.parsers))
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
