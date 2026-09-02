-- Headless test for config.python: which interpreter, pylsp and pyright
-- settings a buffer gets from its project's .python-version.
-- Run: nvim/test/run.sh python_env
--
-- Everything runs against a fake pyenv and python3 on a PATH of its own, fake
-- prefixes under a scratch HOME and a pipx home pointed there through
-- PIPX_HOME, so the spec neither needs pyenv installed nor sees the machine's
-- real pylsp or pipx venv, and every spawn is counted. The fake interpreters
-- fail every import, so a module is found only where site-packages says so.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/python_env_spec.lua$", "")
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

vim.notify = function() end

-- Scratch HOME: pyenv versions under it, a pipx venv where python.lua looks,
-- and two projects, one pinned to a version and one to "system".
local home = vim.fn.tempname()
local bin = home .. "/bin"
local versions = home .. "/versions"
local log = home .. "/pyenv.log"
local pipx = home .. "/.local/share/pipx/venvs/python-lsp-server"
local pinned = home .. "/pinned/src"
local system = home .. "/system"
local unpinned = home .. "/unpinned"
for _, dir in ipairs({ bin, versions, pinned, system, unpinned }) do
  vim.fn.mkdir(dir, "p")
end
local function script(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.list_extend({ "#!/bin/sh" }, lines), path)
  vim.fn.setfperm(path, "rwxr-xr-x")
end
-- pyenv prefix <ver> answers from the versions dir and logs every call.
script(bin .. "/pyenv", {
  'echo "$@" >> ' .. log,
  '[ "$1" = prefix ] && [ -d ' .. versions .. '/"$2" ] && { echo ' .. versions .. '/"$2"; exit 0; }',
  "exit 1",
})
local function pyenv_calls()
  return vim.fn.filereadable(log) == 1 and #vim.fn.readfile(log) or 0
end
script(bin .. "/python3", { "exit 1" })
-- A prefix: bin/python, optionally bin/pylsp, and site-packages modules.
local function prefix(version, opts)
  local root = versions .. "/" .. version
  script(root .. "/bin/python", { "exit 1" })
  if opts.pylsp then
    script(root .. "/bin/pylsp", { "exit 0" })
  end
  for _, module in ipairs(opts.modules or {}) do
    vim.fn.mkdir(root .. "/lib/python3.12/site-packages/" .. module, "p")
  end
  return root
end
local full = prefix("3.12.0", { pylsp = true, modules = { "ipdb", "pylsp_rope" } })
local bare = prefix("3.11.9", {})
vim.fn.writefile({ "3.12.0" }, home .. "/pinned/.python-version")
vim.fn.writefile({ "system" }, system .. "/.python-version")

local original_home, original_path, original_pipx = vim.env.HOME, vim.env.PATH, vim.env.PIPX_HOME
vim.env.HOME = home
vim.env.PATH = bin .. ":/usr/bin:/bin"
vim.env.PIPX_HOME = home .. "/.local/share/pipx"

local python = require("config.python")

local function buffer_in(dir)
  vim.cmd("enew")
  vim.api.nvim_buf_set_name(0, dir .. "/mod.py")
  return vim.api.nvim_get_current_buf()
end
local pinned_buf = buffer_in(pinned)
local system_buf = buffer_in(system)
local unpinned_buf = buffer_in(unpinned)

-- The interpreter: the pinned version's, found through .python-version above
-- the file; "system" and no file fall back to whatever python3 is on PATH.
do
  check("a pinned buffer gets its prefix", python.prefix(pinned_buf) == full, python.prefix(pinned_buf))
  check("and its interpreter", python.python_bin(pinned_buf) == full .. "/bin/python", python.python_bin(pinned_buf))
  check("pyenv was asked once", pyenv_calls() == 1, pyenv_calls())
  python.python_bin(pinned_buf)
  check("the prefix is cached per version", pyenv_calls() == 1, pyenv_calls())
  check("a system-pinned buffer has no prefix", python.prefix(system_buf) == nil, python.prefix(system_buf))
  check("an unpinned buffer has no prefix", python.prefix(unpinned_buf) == nil, python.prefix(unpinned_buf))
  check("system falls back to PATH's python3", python.python_bin(system_buf) == vim.fn.exepath("python3"), python.python_bin(system_buf))
  check("a directory works as the target too", python.python_bin(home .. "/pinned") == full .. "/bin/python", python.python_bin(home .. "/pinned"))
  check("pyenv is not asked for system or missing files", pyenv_calls() == 1, pyenv_calls())
end

-- pylsp: the project's own first, then the pipx venv, then PATH, then bare.
do
  check("pylsp_cmd prefers the prefix's pylsp", vim.deep_equal(python.pylsp_cmd(pinned_buf), { full .. "/bin/pylsp" }), vim.inspect(python.pylsp_cmd(pinned_buf)))
  check("without a pipx venv or PATH pylsp it is the bare name", vim.deep_equal(python.pylsp_cmd(unpinned_buf), { "pylsp" }), vim.inspect(python.pylsp_cmd(unpinned_buf)))

  script(bin .. "/pylsp", { "exit 0" })
  check("a PATH pylsp comes before the bare name", vim.deep_equal(python.pylsp_cmd(unpinned_buf), { bin .. "/pylsp" }), vim.inspect(python.pylsp_cmd(unpinned_buf)))

  script(pipx .. "/bin/pylsp", { "exit 0" })
  script(pipx .. "/bin/python", { "exit 1" })
  check("the pipx venv comes before PATH", vim.deep_equal(python.pylsp_cmd(unpinned_buf), { pipx .. "/bin/pylsp" }), vim.inspect(python.pylsp_cmd(unpinned_buf)))
  check("but after the prefix's own", vim.deep_equal(python.pylsp_cmd(pinned_buf), { full .. "/bin/pylsp" }), vim.inspect(python.pylsp_cmd(pinned_buf)))

  vim.fn.writefile({ "3.11.9" }, home .. "/pinned/.python-version")
  check("a prefix without pylsp falls through to pipx", vim.deep_equal(python.pylsp_cmd(pinned_buf), { pipx .. "/bin/pylsp" }), vim.inspect(python.pylsp_cmd(pinned_buf)))
  vim.fn.writefile({ "3.12.0" }, home .. "/pinned/.python-version")
end

-- Modules: answered from site-packages on disk, no interpreter spawned, and
-- cached per interpreter as a copy the caller cannot corrupt.
do
  local ipdb = python.module_status("ipdb", pinned_buf)
  check("a module in site-packages is available", ipdb.available == true and ipdb.python == full .. "/bin/python", vim.inspect(ipdb))
  local missing = python.module_status("nothing_here", pinned_buf)
  check("a missing module says which interpreter lacks it", missing.available == false and missing.detail == "nothing_here (missing in " .. full .. "/bin/python)", vim.inspect(missing))
  ipdb.available = false
  check("the cached status is handed out as a copy", python.module_status("ipdb", pinned_buf).available == true)
  local none = python.module_status_for_python("ipdb", nil)
  check("no interpreter is its own answer", none.available == false and none.detail == "ipdb (no python interpreter)", vim.inspect(none))
  check("module_available is the boolean of the same", python.module_available("ipdb", pinned_buf) == true)
end

-- pylsp-rope: the check follows the pylsp that would run and looks for the
-- plugin next to it.
do
  local ok = python.pylsp_status(pinned_buf)
  check("pylsp with rope in its prefix is available", ok.available == true and ok.path == full .. "/bin/pylsp", vim.inspect(ok))

  local pipx_status = python.pylsp_status(unpinned_buf)
  check("the pipx pylsp without rope names the fix", pipx_status.available == false and pipx_status.detail:find("pipx inject python%-lsp%-server pylsp%-rope") ~= nil, vim.inspect(pipx_status))
  check("and the path it checked", pipx_status.path == pipx .. "/bin/pylsp", pipx_status.path)

  vim.fn.delete(pipx, "rf")
  vim.fn.delete(bin .. "/pylsp")
  local absent = python.pylsp_status(unpinned_buf)
  check("no pylsp at all asks for the pipx install", absent.available == false and absent.detail == "pylsp (pipx install python-lsp-server)", vim.inspect(absent))
end

-- pyright: the interpreter and venv of the project root, with the analysis
-- settings that keep a large repo quiet.
do
  local settings = python.pyright_settings(home .. "/pinned")
  check("pyright gets the project's interpreter", settings.python.pythonPath == full .. "/bin/python", settings.python.pythonPath)
  check("and its venv split into path and name", settings.python.venvPath == versions and settings.python.venv == "3.12.0", vim.inspect({ settings.python.venvPath, settings.python.venv }))
  check("diagnostics are for open files only", settings.python.analysis.diagnosticMode == "openFilesOnly", settings.python.analysis.diagnosticMode)
  check("caches are excluded from analysis", vim.list_contains(settings.python.analysis.exclude, "**/.mypy_cache"), vim.inspect(settings.python.analysis.exclude))

  local plain = python.pyright_settings(unpinned)
  check("an unpinned root has no venv", plain.python.venvPath == nil and plain.python.venv == nil, vim.inspect(plain.python))
  check("but still an interpreter from PATH", plain.python.pythonPath == vim.fn.exepath("python3"), plain.python.pythonPath)
end

-- activate(): the prefix's bin leads PATH and VIRTUAL_ENV is set while a pinned
-- buffer is current; a buffer without one clears both, and re-activating the
-- same prefix adds no second PATH entry.
do
  local path_before = vim.env.PATH
  python.activate(pinned_buf)
  check("activate prepends the prefix bin", vim.startswith(vim.env.PATH, full .. "/bin:"), vim.env.PATH:sub(1, #full + 10))
  check("activate sets VIRTUAL_ENV", vim.env.VIRTUAL_ENV == full, vim.env.VIRTUAL_ENV)
  check("active_prefix reports it", python.active_prefix() == full, python.active_prefix())
  python.activate(pinned_buf)
  check("re-activating adds nothing", select(2, vim.env.PATH:gsub(vim.pesc(full .. "/bin"), "")) == 1, vim.env.PATH)
  python.activate(unpinned_buf)
  check("an unpinned buffer clears the PATH entry", vim.env.PATH == path_before, vim.env.PATH)
  check("and VIRTUAL_ENV", vim.env.VIRTUAL_ENV == nil, vim.env.VIRTUAL_ENV)
end

vim.env.HOME, vim.env.PATH, vim.env.PIPX_HOME = original_home, original_path, original_pipx
vim.fn.delete(home, "rf")

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
