-- Headless test for config.linters: which nvim-lint linters a filetype gets.
-- Run: nvim/test/run.sh linters
--
-- The selection used to be rebuilt for every filetype on every read and write
-- of any buffer, probing all seven tools each time. It is now resolved for the
-- filetype being linted only, against an availability predicate, so this is
-- pure and the probing cost is decided by the caller.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/linters_spec.lua$", "")
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

local linters = require("config.linters")

local function only(set)
  return function(bin)
    return set[bin] == true
  end
end

local function same(a, b)
  return vim.deep_equal(a, b)
end

-- Python: mypy, else pylint, else flake8; ruff is never a linter here because
-- its diagnostics come from the ruff LSP server.
do
  local got = linters.for_filetype("python", only({ mypy = true, pylint = true, flake8 = true }))
  check("python prefers mypy", same(got, { "mypy" }), vim.inspect(got))
  got = linters.for_filetype("python", only({ pylint = true, flake8 = true }))
  check("python falls back to pylint", same(got, { "pylint" }), vim.inspect(got))
  got = linters.for_filetype("python", only({ flake8 = true }))
  check("python falls back to flake8", same(got, { "flake8" }), vim.inspect(got))
  got = linters.for_filetype("python", only({ ruff = true }))
  check("python never lints with ruff", same(got, {}), vim.inspect(got))
  got = linters.for_filetype("python", only({}))
  check("python with nothing installed is empty", same(got, {}), vim.inspect(got))
end

-- Shells share shellcheck; the other filetypes have one linter each.
do
  for _, ft in ipairs({ "bash", "sh", "zsh" }) do
    local got = linters.for_filetype(ft, only({ shellcheck = true }))
    check(ft .. " uses shellcheck", same(got, { "shellcheck" }), vim.inspect(got))
    got = linters.for_filetype(ft, only({}))
    check(ft .. " without shellcheck is empty", same(got, {}), vim.inspect(got))
  end
  check("terraform uses tflint", same(linters.for_filetype("terraform", only({ tflint = true })), { "tflint" }))
  check("terraform without tflint is empty", same(linters.for_filetype("terraform", only({})), {}))
  check("yaml uses yamllint", same(linters.for_filetype("yaml", only({ yamllint = true })), { "yamllint" }))
end

-- A filetype with no linters configured is nil, not an empty list, so the
-- caller can leave nvim-lint's table untouched for it.
do
  check("unknown filetype is nil", linters.for_filetype("lua", only({ stylua = true })) == nil)
  check("empty filetype is nil", linters.for_filetype("", only({})) == nil)
end

-- Only the filetype's own tools are asked about.
do
  local asked = {}
  linters.for_filetype("terraform", function(bin)
    table.insert(asked, bin)
    return true
  end)
  check("terraform asks about tflint only", same(asked, { "tflint" }), vim.inspect(asked))

  asked = {}
  linters.for_filetype("python", function(bin)
    table.insert(asked, bin)
    return bin == "mypy"
  end)
  check("python stops asking once mypy is found", same(asked, { "mypy" }), vim.inspect(asked))
end

-- The configured filetypes, for the caller that wants to seed or list them.
do
  check(
    "filetypes lists every configured filetype",
    same(linters.filetypes(), { "bash", "python", "sh", "terraform", "yaml", "zsh" }),
    vim.inspect(linters.filetypes())
  )
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
