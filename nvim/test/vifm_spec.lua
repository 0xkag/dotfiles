-- Headless test for plugins.vifm and its config.deps features: vifm in a
-- terminal buffer, the one file manager here whose preview pane shows images
-- (as colored text, through ~/.dotfiles/vifm/vifmrc and image-view) in a
-- terminal without the kitty graphics protocol.
-- Run: nvim/test/run.sh vifm
--
-- The plugin comes from its own repository through lazy.nvim rather than the
-- copy vifm installs, whose location depends on how vifm was installed (flox
-- is not on every machine).
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/vifm_spec.lua$", "")
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

local util = require("config.util")
local root = "/work/some project"
util.project_root = function()
  return root
end

local ok, spec = pcall(require, "plugins.vifm")
check("plugins.vifm loads", ok, spec)
spec = ok and spec or {}

check("the plugin is vifm.vim from its repository", spec[1] == "vifm/vifm.vim", spec[1])
check("it loads on :Vifm", vim.tbl_contains(spec.cmd or {}, "Vifm"), vim.inspect(spec.cmd))

-- lazy.nvim's stubs for `keys` are expr mappings that load the plugin, and
-- vifm.vim probes for :drop as it loads by running a bare `drop`, which an expr
-- mapping's textlock turns into E565. So the keys are plain mappings made in
-- `init` that run :Vifm, and lazy's command stub loads the plugin instead.
check("the keys are not lazy key stubs", spec.keys == nil, vim.inspect(spec.keys))
check("the keys are made in init", type(spec.init) == "function", type(spec.init))
if type(spec.init) == "function" then
  spec.init()
end

local function mapping(lhs)
  local map = vim.fn.maparg(lhs, "n", false, true)
  return not vim.tbl_isempty(map) and map or nil
end

-- Stand in a command declared the way vifm.vim declares :Vifm, which hands its
-- arguments over as <f-args>, splitting on unescaped whitespace when typed.
vim.cmd("command! -bar -nargs=* -count -complete=dir Vifm let g:vifm_fargs = [<f-args>]")

do
  local map = mapping("<leader>ov")
  check("<leader>ov opens vifm", map and map.rhs == "<cmd>Vifm<cr>", map and vim.inspect(map.rhs))
  check("<leader>ov is not an expr mapping", map and map.expr == 0, map and map.expr)
  check("<leader>ov has a description", map and map.desc == "File manager (vifm)", map and map.desc)
end

do
  local map = mapping("<leader>oV")
  check("<leader>oV is a function", map and type(map.callback) == "function", map and type(map.callback))
  check("<leader>oV is not an expr mapping", map and map.expr == 0, map and map.expr)
  if map and type(map.callback) == "function" then
    map.callback()
  end
  check("<leader>oV opens the project root as one argument", vim.deep_equal(vim.g.vifm_fargs, { root }), vim.inspect(vim.g.vifm_fargs))
  check("<leader>oV has a description", map and map.desc == "Project file manager (vifm)", map and map.desc)
end

-- :checkhealth config reports vifm, and separately what its image previews
-- need, since vifm works without them.
local tools = require("config.tools")
local unavailable = {}
tools.status = function(bin)
  if unavailable[bin] then
    return { available = false, bin = bin, detail = bin, reason = "not found" }
  end
  return { available = true, bin = bin, path = "/fake/bin/" .. bin }
end
tools.invalidate = function() end

local function core_report(missing)
  unavailable = missing
  local by_id = {}
  for _, entry in ipairs(require("config.deps").report().core) do
    by_id[entry.id] = entry
  end
  return by_id
end

do
  local report = core_report({ chafa = true })
  local manager = report.file_manager
  check("vifm is an editor-wide feature", manager ~= nil, vim.inspect(vim.tbl_keys(report)))
  check("an installed vifm is ok, naming it", manager and manager.ok and manager.line == "File manager (vifm): vifm", manager and manager.line)

  local images = report.file_manager_images
  check("its image previews are a feature of their own", images ~= nil, vim.inspect(vim.tbl_keys(report)))
  check("a missing chafa is reported against the previews", images and not images.ok and images.line:find("chafa", 1, true) ~= nil, images and images.line)
end

do
  local images = core_report({ ["image-view"] = true }).file_manager_images
  check("so is a missing image-view", images and not images.ok and images.line:find("image-view", 1, true) ~= nil, images and images.line)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
