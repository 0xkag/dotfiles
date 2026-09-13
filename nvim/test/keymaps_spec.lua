-- Headless test for keymap hygiene: config.keymaps, and the buffer-local maps
-- kulala.lua adds.
-- Run: nvim/test/run.sh keymaps
--
-- Neovim 0.11 ships grn / grr / gri / gra / grt as default LSP mappings. This
-- config maps `gr` itself (references, Spacemacs muscle memory), and with both
-- present every `gr` waits the full timeoutlen for a possible third key. The
-- defaults are deleted so `gr` fires at once; `gO` has no such clash and stays.
--
-- Beyond that: no key repeats another under a different name, every map has a
-- desc for which-key to show, and a buffer-local leaf that shares its key with
-- a global which-key group registers its own label, or which-key shows the
-- group's name over it.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/keymaps_spec.lua$", "")
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

local function mapped(lhs, mode)
  return vim.fn.maparg(lhs, mode or "n") ~= ""
end

-- Every map in every mode, so the config's own maps can be told from Neovim's.
local function keymaps()
  local seen = {}
  for _, mode in ipairs({ "n", "x", "v", "i", "t", "o" }) do
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      seen[mode .. " " .. map.lhs] = map
    end
  end
  return seen
end
local defaults = keymaps()

-- The defaults are there before the config runs, or this spec proves nothing.
check("grn is a default before the config", mapped("grn"))
check("gra is a default in visual mode before the config", mapped("gra", "x"))

require("config.keymaps")

for _, lhs in ipairs({ "grn", "grr", "gri", "gra", "grt" }) do
  check(lhs .. " default is gone", not mapped(lhs), vim.fn.maparg(lhs, "n"))
end
check("gra default is gone in visual mode", not mapped("gra", "x"), vim.fn.maparg("gra", "x"))
check("gO default stays", mapped("gO"))
check("gr is mapped", mapped("gr"), vim.fn.maparg("gr", "n"))
check("gd is mapped", mapped("gd"), vim.fn.maparg("gd", "n"))

-- Maps that restate Neovim's own defaults are not repeated: `Y` is `y$` since
-- 0.6. The LSP buffer keys (`[d` / `]d` left to Neovim, `K` kept for its
-- border, the retired `,gA` `,gR` `,gS` `,gt`) are config.lsp_keymaps now and
-- lsp_keymaps_spec drives them against a fake client.
check("Y keeps Neovim's default mapping", vim.fn.maparg("Y", "n", false, true).desc == ":help Y-default", vim.inspect(vim.fn.maparg("Y", "n", false, true)))

-- One key per action. `<leader>tl` is a wanted alias of `SPC tvt`, and
-- documented as one, so it stays.
do
  local tvt = vim.fn.maparg("<leader>tvt", "n", false, true)
  local tl = vim.fn.maparg("<leader>tl", "n", false, true)
  check("<leader>tvt is mapped", tvt.callback ~= nil, vim.inspect(tvt))
  check("<leader>tl is mapped", tl.callback ~= nil, vim.inspect(tl))
  local before = vim.wo.list
  if tl.callback then
    tl.callback()
  end
  check("<leader>tl toggles list", vim.wo.list ~= before, vim.wo.list)
  if tvt.callback then
    tvt.callback()
  end
  check("<leader>tvt toggles it back", vim.wo.list == before, vim.wo.list)
end

-- Every map config.keymaps adds carries a desc; which-key shows the raw rhs
-- for one without.
do
  local undescribed = {}
  for key, map in pairs(keymaps()) do
    local before = defaults[key]
    local ours = not before or before.rhs ~= map.rhs or before.callback ~= map.callback
    if ours and (map.desc == nil or map.desc == "") then
      table.insert(undescribed, key)
    end
  end
  table.sort(undescribed)
  check("every map config.keymaps sets has a desc", #undescribed == 0, table.concat(undescribed, ", "))
end

-- kulala's buffer-local `,r`, `,a` and `,i` share their key with the global
-- refactor, action and insert/import groups, so which-key would show the
-- group's name over the map's own; the http FileType registers labels the
-- way the git editors do.
do
  local added = {}
  package.preload["kulala"] = function()
    return { setup = function() end }
  end
  package.preload["which-key"] = function()
    return {
      add = function(specs)
        vim.list_extend(added, specs)
      end,
    }
  end
  package.preload["which-key.config"] = function()
    return { loaded = true }
  end
  local spec = require("plugins.kulala")
  spec.config(spec, spec.opts)

  vim.cmd("enew")
  vim.bo.filetype = "http"
  local buf = vim.api.nvim_get_current_buf()
  local run = vim.fn.maparg("<localleader>r", "n", false, true)
  check("an http buffer gets the kulala maps", run.buffer == 1, vim.inspect(run))

  local labels = {}
  for _, item in ipairs(added) do
    if item.buffer == buf and item.desc then
      labels[item[1]] = item.desc
    end
  end
  for _, lhs in ipairs({ "<localleader>a", "<localleader>i", "<localleader>r" }) do
    check(lhs .. " labels itself over the global group", labels[lhs] ~= nil, vim.inspect(added))
  end
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
