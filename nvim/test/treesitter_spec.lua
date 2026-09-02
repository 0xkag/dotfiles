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

-- attach(): starts the highlighter and, only then, marks the buffer for
-- treesitter folding and hands its indent to treesitter. foldexpr() is the
-- global 'foldexpr': it defers to vim.treesitter.foldexpr() for a marked buffer
-- and answers "0" for any other, so a buffer without a parser never pays for a
-- parser lookup per line. The mark is per buffer because a window-local option
-- set at attach time stays with the window and leaks to every later buffer
-- shown in it.
do
  vim.cmd("enew")
  vim.bo.indentexpr = ""
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local function f()", "  return 1", "end" })
  local buf = vim.api.nvim_get_current_buf()
  check("attach starts treesitter for a parsed filetype", treesitter.attach(buf) == true)
  check("attach highlights the buffer", vim.treesitter.highlighter.active[buf] ~= nil)
  check("attach marks the buffer for treesitter folds", vim.b[buf].ts_folds == true, vim.inspect(vim.b[buf].ts_folds))
  check("foldexpr folds a marked buffer", treesitter.foldexpr(1) ~= "0", treesitter.foldexpr(1))
  check("attach indents by nvim-treesitter", vim.bo.indentexpr == "v:lua.require'nvim-treesitter'.indentexpr()", vim.bo.indentexpr)

  vim.cmd("enew")
  vim.bo.indentexpr = ""
  vim.bo.filetype = "zzz_no_such_language"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "function f()", "  return 1", "end" })
  local plain = vim.api.nvim_get_current_buf()
  check("attach declines a filetype without a parser", treesitter.attach(plain) == false)
  check("no parser leaves the buffer unmarked", vim.b[plain].ts_folds == nil, vim.inspect(vim.b[plain].ts_folds))
  check("foldexpr answers 0 for an unmarked buffer in the same window", treesitter.foldexpr(1) == "0", treesitter.foldexpr(1))
  check("no parser leaves indent alone", vim.bo.indentexpr == "", vim.bo.indentexpr)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
