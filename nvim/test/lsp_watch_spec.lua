-- Headless test harness for config.lsp_watch pure helpers and the
-- capability-suppression decision. Run:
--   nvim --headless -u NONE -l nvim/test/lsp_watch_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/lsp_watch_spec.lua$", "")
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

local uv = vim.uv or vim.loop
local lsp_watch = require("config.lsp_watch")

-- backend(): mirrors the _watchfiles.lua selection under faked has/executable.
do
  local orig_has, orig_exe = vim.fn.has, vim.fn.executable
  local function fake(has_map, exe_map)
    vim.fn.has = function(f)
      return has_map[f] or 0
    end
    vim.fn.executable = function(b)
      return exe_map[b] or 0
    end
  end
  local function restore()
    vim.fn.has, vim.fn.executable = orig_has, orig_exe
  end

  fake({ mac = 1 }, {})
  check("backend mac -> fsevent", lsp_watch.backend() == "fsevent", lsp_watch.backend())

  fake({ win32 = 1 }, {})
  check("backend win32 -> fsevent", lsp_watch.backend() == "fsevent", lsp_watch.backend())

  fake({}, { inotifywait = 1 })
  check("backend inotifywait -> inotify", lsp_watch.backend() == "inotify", lsp_watch.backend())

  fake({}, {})
  check("backend fallback -> watchdirs", lsp_watch.backend() == "watchdirs", lsp_watch.backend())
  check("native_watch_available false for watchdirs", lsp_watch.native_watch_available() == false)

  fake({}, { inotifywait = 1 })
  check("native_watch_available true for inotify", lsp_watch.native_watch_available() == true)

  restore()
end

-- tree_is_huge(): early-break when the directory count exceeds the cap.
do
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  -- Small tree: a handful of dirs, well under any sane cap.
  for i = 1, 3 do
    vim.fn.mkdir(tmp .. "/d" .. i, "p")
  end
  check("tree_is_huge small=false", lsp_watch.tree_is_huge(tmp, 100) == false)

  -- Synthetic large tree relative to a tiny cap.
  local big = vim.fn.tempname()
  vim.fn.mkdir(big, "p")
  for i = 1, 12 do
    vim.fn.mkdir(big .. "/d" .. i, "p")
  end
  check("tree_is_huge over cap=true", lsp_watch.tree_is_huge(big, 5) == true)

  -- Nonexistent path: filesystem error must not read as "huge".
  check("tree_is_huge missing=false", lsp_watch.tree_is_huge(big .. "/nope", 1) == false)

  vim.fn.delete(tmp, "rf")
  vim.fn.delete(big, "rf")
end

-- maybe_suppress(): flips dynamicRegistration to false only for watchdirs +
-- huge tree; leaves native backends and small trees untouched.
do
  local orig_backend, orig_huge = lsp_watch.backend, lsp_watch.tree_is_huge
  local function fake_client()
    return {
      id = 1,
      name = "terraformls",
      root_dir = "/some/huge/repo",
      capabilities = {},
    }
  end
  local function dyn(client)
    return vim.tbl_get(client.capabilities, "workspace", "didChangeWatchedFiles", "dynamicRegistration")
  end

  -- watchdirs + huge -> suppressed.
  lsp_watch.backend = function() return "watchdirs" end
  lsp_watch.tree_is_huge = function() return true end
  local c1 = fake_client()
  lsp_watch.maybe_suppress(c1)
  check("suppress watchdirs+huge sets false", dyn(c1) == false, tostring(dyn(c1)))

  -- watchdirs + small -> untouched.
  lsp_watch.tree_is_huge = function() return false end
  local c2 = fake_client()
  lsp_watch.maybe_suppress(c2)
  check("no suppress watchdirs+small", dyn(c2) == nil, tostring(dyn(c2)))

  -- native backend + huge -> untouched.
  lsp_watch.backend = function() return "inotify" end
  lsp_watch.tree_is_huge = function() return true end
  local c3 = fake_client()
  lsp_watch.maybe_suppress(c3)
  check("no suppress native+huge", dyn(c3) == nil, tostring(dyn(c3)))

  lsp_watch.backend, lsp_watch.tree_is_huge = orig_backend, orig_huge
  -- maybe_suppress may have registered a HEAD watcher for c1 if the test repo
  -- root happened to exist; clean up defensively so no handles leak.
  lsp_watch.cleanup(1)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
