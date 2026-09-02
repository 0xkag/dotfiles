-- Headless test for the module-scoped tflint linter in config.tflint.
-- Run: nvim/test/run.sh tflint
--
-- The scoped linter runs tflint with the edited file's directory as the process
-- cwd and no --filter: tflint matches --filter against paths relative to its
-- own cwd, so pairing it with an absolute --chdir silently matched nothing and
-- the linter reported zero issues. Scoping by cwd needs no filter at all; the
-- parser keeps only the issues in the edited file, resolving each issue's
-- cwd-relative filename against the directory the process ran in.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/tflint_spec.lua$", "")
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

local tflint = require("config.tflint")

-- The upstream linter definition, as nvim-lint ships it: --recursive scans the
-- whole repo, and its parser compares cwd-relative names.
local upstream = {
  cmd = "tflint",
  args = { "--format=json", "--recursive" },
  append_fname = false,
  stdin = false,
  ignore_exitcode = true,
  parser = function() end,
}

local module_dir = vim.fn.tempname()
vim.fn.mkdir(module_dir, "p")
local main_tf = module_dir .. "/main.tf"
vim.fn.writefile({ 'resource "x" "y" {}' }, main_tf)

-- linter(): runs in the file's directory, with neither --recursive nor --filter.
do
  local linter = tflint.linter(upstream, main_tf)
  check("linter keeps the upstream cmd", linter.cmd == "tflint", linter.cmd)
  check("linter cwd is the module dir", linter.cwd == module_dir, linter.cwd)
  check("linter args are json only", vim.deep_equal(linter.args, { "--format=json" }), vim.inspect(linter.args))
  check("linter does not append the file name", linter.append_fname == false, linter.append_fname)
  check("linter ignores the exit code", linter.ignore_exitcode == true, linter.ignore_exitcode)
  check("linter parser is ours", linter.parser == tflint.parse, linter.parser)
  check("upstream args are untouched", vim.deep_equal(upstream.args, { "--format=json", "--recursive" }), vim.inspect(upstream.args))
end

-- Real tflint 0.61 output for a module with an unused variable on line 5 and a
-- second file the parser must ignore. HCL ranges are 1-based with an exclusive
-- end column; vim.Diagnostic wants 0-based.
local output = vim.json.encode({
  issues = {
    {
      rule = {
        name = "terraform_unused_declarations",
        severity = "warning",
        link = "https://example.invalid/unused",
      },
      message = 'variable "unused" is declared but not used',
      range = {
        filename = "main.tf",
        start = { line = 5, column = 1 },
        ["end"] = { line = 5, column = 18 },
      },
    },
    {
      rule = {
        name = "terraform_required_version",
        severity = "error",
        link = "https://example.invalid/version",
      },
      message = "terraform version constraint is required",
      range = {
        filename = "versions.tf",
        start = { line = 1, column = 1 },
        ["end"] = { line = 1, column = 1 },
      },
    },
  },
  errors = {},
})

-- parse(): keeps the edited file's issues, dropping the sibling file's.
do
  local bufnr = vim.fn.bufadd(main_tf)
  local diagnostics = tflint.parse(output, bufnr, module_dir)
  check("parse keeps one issue for the buffer", #diagnostics == 1, #diagnostics)
  local d = diagnostics[1] or {}
  check("parse lnum is 0-based", d.lnum == 4, d.lnum)
  check("parse col is 0-based", d.col == 0, d.col)
  check("parse end_lnum is 0-based", d.end_lnum == 4, d.end_lnum)
  check("parse end_col stays exclusive", d.end_col == 17, d.end_col)
  check("parse severity maps warning", d.severity == vim.diagnostic.severity.WARN, d.severity)
  check("parse source is tflint", d.source == "tflint", d.source)
  check("parse message names the rule", d.message and d.message:find("(terraform_unused_declarations)", 1, true) ~= nil, d.message)
  check("parse message carries the link", d.message and d.message:find("https://example.invalid/unused", 1, true) ~= nil, d.message)
end

-- parse(): a filename reported relative to a different cwd still resolves, so a
-- run from elsewhere (tflint reports ../-style paths then) is matched too.
do
  local bufnr = vim.fn.bufadd(main_tf)
  local parent = vim.fs.dirname(module_dir)
  local relative = vim.fs.basename(module_dir) .. "/main.tf"
  local shifted = output:gsub('"main%.tf"', '"' .. relative .. '"')
  local diagnostics = tflint.parse(shifted, bufnr, parent)
  check("parse resolves against the linter cwd", #diagnostics == 1, #diagnostics)
end

-- parse(): errors and empty output are no diagnostics, not an exception.
do
  local bufnr = vim.fn.bufadd(main_tf)
  check("parse tolerates empty output", #tflint.parse("", bufnr, module_dir) == 0)
  check("parse tolerates an error-only report", #tflint.parse('{"issues":[],"errors":[{"message":"x"}]}', bufnr, module_dir) == 0)
end

-- module_dir(): the directory holding the buffer's file.
do
  check("module_dir is the file's directory", tflint.module_dir(main_tf) == module_dir, tflint.module_dir(main_tf))
end

vim.fn.delete(module_dir, "rf")

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
