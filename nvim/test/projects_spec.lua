-- Headless test for the recent-projects list in config.projects.
-- Run: nvim/test/run.sh projects
--
-- The list is tracked from BufEnter, so it has to be cheap and it must never
-- throw: a state file that cannot be written warns once instead of erroring on
-- every buffer switch, a project whose directory is missing (an unmounted
-- share) stays in the file and is only hidden from the picker, and re-entering
-- a buffer of the project already at the head does not rewrite the file.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/projects_spec.lua$", "")
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

local notes = {}
vim.notify = function(msg, level)
  table.insert(notes, { level = level, msg = msg })
end

local projects = require("config.projects")

local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch, "p")
local state_dir = scratch .. "/state"
local state_file = state_dir .. "/projects.txt"
projects._set_state_file(state_file)

-- Two real project roots (a .git dir is a root marker) and one that no longer
-- exists.
local function project(name)
  local dir = scratch .. "/" .. name
  vim.fn.mkdir(dir .. "/.git", "p")
  vim.fn.writefile({ name }, dir .. "/file.txt")
  return vim.fs.normalize(dir), dir .. "/file.txt"
end
local proj_a, file_a = project("a")
local proj_b, file_b = project("b")
local gone = vim.fs.normalize(scratch .. "/gone")

local function file_lines()
  return vim.fn.filereadable(state_file) == 1 and vim.fn.readfile(state_file) or nil
end

-- add(): writes the head, most recent first, creating the state dir.
do
  check("add returns the path", projects.add(proj_a, { silent = true }) == proj_a)
  check("add creates the state file", vim.deep_equal(file_lines(), { proj_a }), vim.inspect(file_lines()))
  projects.add(proj_b, { silent = true })
  check("add puts the newest first", vim.deep_equal(file_lines(), { proj_b, proj_a }), vim.inspect(file_lines()))
  local leftovers = vim.fn.glob(state_dir .. "/*", false, true)
  check("add leaves no temp file behind", #leftovers == 1, vim.inspect(leftovers))
end

-- A missing directory stays in the file but is hidden from the list.
do
  vim.fn.writefile({ gone, proj_a, proj_b }, state_file)
  local listed = projects.list()
  check("list hides a missing directory", vim.deep_equal(listed, { proj_a, proj_b }), vim.inspect(listed))
  check("list does not rewrite the file", vim.deep_equal(file_lines(), { gone, proj_a, proj_b }), vim.inspect(file_lines()))
  projects.add(proj_b, { silent = true })
  check("add keeps the missing directory on file", vim.tbl_contains(file_lines(), gone), vim.inspect(file_lines()))
end

-- track(): a buffer of the project already at the head does not rewrite the
-- file. The duplicate entry is the tell: a rewrite would dedupe it.
do
  vim.fn.writefile({ proj_a, proj_a, proj_b }, state_file)
  vim.cmd("edit " .. vim.fn.fnameescape(file_a))
  projects.track(0)
  check("track leaves the file alone when the head is unchanged", vim.deep_equal(file_lines(), { proj_a, proj_a, proj_b }), vim.inspect(file_lines()))

  vim.cmd("edit " .. vim.fn.fnameescape(file_b))
  projects.track(0)
  check("track moves a new head to the front", vim.deep_equal(file_lines(), { proj_b, proj_a }), vim.inspect(file_lines()))
end

-- An unwritable state file warns once and never throws.
do
  notes = {}
  local blocker = scratch .. "/blocker"
  vim.fn.writefile({ "not a directory" }, blocker)
  projects._set_state_file(blocker .. "/projects.txt")

  vim.cmd("edit " .. vim.fn.fnameescape(file_a))
  local ok, err = pcall(projects.track, 0)
  check("track survives an unwritable state file", ok, err)
  local warnings = vim.tbl_filter(function(note)
    return note.level == vim.log.levels.WARN
  end, notes)
  check("unwritable state file warns", #warnings == 1, vim.inspect(notes))

  vim.cmd("edit " .. vim.fn.fnameescape(file_b))
  ok, err = pcall(projects.track, 0)
  check("second failure still does not throw", ok, err)
  warnings = vim.tbl_filter(function(note)
    return note.level == vim.log.levels.WARN
  end, notes)
  check("unwritable state file warns only once", #warnings == 1, vim.inspect(notes))

  projects._set_state_file(state_file)
end

-- remove(): drops the entry and reports whether it was there.
do
  vim.fn.writefile({ proj_a, proj_b }, state_file)
  check("remove drops a listed project", projects.remove(proj_a, { silent = true }) == true)
  check("remove rewrites without it", vim.deep_equal(file_lines(), { proj_b }), vim.inspect(file_lines()))
  check("remove reports an unlisted project", projects.remove(proj_a, { silent = true }) == false)
end

vim.fn.delete(scratch, "rf")

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
