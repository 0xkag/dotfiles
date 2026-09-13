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

-- bash and sh share shellcheck; zsh gets nothing, since shellcheck does not
-- parse it; the other filetypes have one linter each.
do
  for _, ft in ipairs({ "bash", "sh" }) do
    local got = linters.for_filetype(ft, only({ shellcheck = true }))
    check(ft .. " uses shellcheck", same(got, { "shellcheck" }), vim.inspect(got))
    got = linters.for_filetype(ft, only({}))
    check(ft .. " without shellcheck is empty", same(got, {}), vim.inspect(got))
  end
  check("zsh has no linter even with shellcheck installed", linters.for_filetype("zsh", only({ shellcheck = true })) == nil, vim.inspect(linters.for_filetype("zsh", only({ shellcheck = true }))))
  check("terraform uses tflint", same(linters.for_filetype("terraform", only({ tflint = true })), { "tflint" }))
  check("terraform without tflint is empty", same(linters.for_filetype("terraform", only({})), {}))
  check("yaml uses yamllint", same(linters.for_filetype("yaml", only({ yamllint = true })), { "yamllint" }))
end

-- mypy takes 1-3 s per run and only says what pyright already says about the
-- file as it stands, so it runs on write only: a read of a Python buffer gets
-- no linter rather than the next candidate, since pylint would cost the same.
do
  local got = linters.for_filetype("python", only({ mypy = true, pylint = true }), { on_read = true })
  check("python on read runs nothing when mypy is the pick", same(got, {}), vim.inspect(got))
  got = linters.for_filetype("python", only({ mypy = true, pylint = true }))
  check("python on write runs mypy", same(got, { "mypy" }), vim.inspect(got))
  got = linters.for_filetype("python", only({ pylint = true }), { on_read = true })
  check("pylint still runs on read", same(got, { "pylint" }), vim.inspect(got))
  got = linters.for_filetype("yaml", only({ yamllint = true }), { on_read = true })
  check("other filetypes lint on read", same(got, { "yamllint" }), vim.inspect(got))
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
    same(linters.filetypes(), { "bash", "python", "sh", "terraform", "yaml" }),
    vim.inspect(linters.filetypes())
  )
end

-- The plugin wiring: BufReadPost and BufWritePost resolve the buffer's
-- filetype through the same function, with the read marked as one, and the
-- <leader>el key lints as a write does. nvim-lint itself is a stub that
-- records what it was handed.
do
  local stub = { linters = {}, linters_by_ft = {}, tries = 0 }
  stub.try_lint = function()
    stub.tries = stub.tries + 1
  end
  package.preload["lint"] = function()
    return stub
  end
  package.preload["lint.linters.tflint"] = function()
    return {}
  end
  local tools = require("config.tools")
  tools.status = function(bin)
    return { available = bin == "mypy", bin = bin }
  end
  require("plugins.lint").config()

  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].filetype = "python"
  vim.api.nvim_exec_autocmds("BufReadPost", { buffer = buf })
  check("a read hands nvim-lint no python linter", same(stub.linters_by_ft.python, {}), vim.inspect(stub.linters_by_ft.python))
  check("but still asks it to lint", stub.tries == 1, stub.tries)
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf })
  check("a write hands it mypy", same(stub.linters_by_ft.python, { "mypy" }), vim.inspect(stub.linters_by_ft.python))
  stub.linters_by_ft.python = nil
  vim.fn.maparg("<leader>el", "n", false, true).callback()
  check("<leader>el lints like a write", same(stub.linters_by_ft.python, { "mypy" }) and stub.tries == 3, vim.inspect({ stub.linters_by_ft.python, stub.tries }))
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
