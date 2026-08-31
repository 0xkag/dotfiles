-- Headless test for the neo-tree plain glyph profile (<leader>tg) in
-- plugins/neotree.lua.
-- Run: nvim --headless -u NONE -l nvim/test/neotree_symbols_spec.lua
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/neotree_symbols_spec.lua$", "")
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

-- Stub neo-tree down to what the profile touches: each source's components
-- module, which in the real plugin is a merge of the common components with the
-- source's own. Every stub component echoes the config it was handed, which is
-- exactly what the profile is supposed to rewrite.
local components = { "git_status", "icon", "indent" }
local sources = { "buffers", "filesystem", "git_status" }
local function echo(name)
  return function(config)
    return { component = name, config = config }
  end
end
for _, source in ipairs(sources) do
  package.preload["neo-tree.sources." .. source .. ".components"] = function()
    local module = {}
    for _, name in ipairs(components) do
      module[name] = echo(name)
    end
    return module
  end
end
package.preload["neo-tree.sources.manager"] = function()
  return {
    get_state = function()
      return { path = "/nowhere" }
    end,
    refresh = function() end,
  }
end
package.preload["neo-tree.events"] = function()
  return {
    GIT_STATUS_CHANGED = "git_status_changed",
    subscribe = function() end,
  }
end
local setup_calls = 0
package.preload["neo-tree"] = function()
  return {
    setup = function()
      setup_calls = setup_calls + 1
    end,
  }
end

local notes = {}
vim.notify = function(msg)
  if type(msg) == "string" and msg:find("^neo%-tree glyphs") then
    table.insert(notes, msg)
  end
end

local spec = require("plugins.neotree")
local maps = {}
for _, k in ipairs(spec.keys) do
  maps[k[1]] = k[2]
end

-- config() wraps the components before setup, because neo-tree reads each
-- source's components module to decide what its renderers may use.
spec.config(nil, spec.opts)
check("config sets neo-tree up once", setup_calls == 1, setup_calls)

local registered = {}
for _, source in ipairs(sources) do
  registered[source] = require("neo-tree.sources." .. source .. ".components")
end
-- Each source wraps its own component, so the closures differ between sources
-- by design; what has to hold is that all three are wrapped. A wrapped
-- git_status rewrites the symbols it was handed, a bare one echoes them back.
for _, source in ipairs(sources) do
  local out = registered[source].git_status({ symbols = { modified = "GLYPH" } }, nil, nil)
  check(source .. " has its git_status wrapped", out.config.symbols.modified == "M", out.config.symbols.modified)
end
for _, name in ipairs(components) do
  local present = true
  for _, source in ipairs(sources) do
    present = present and type(registered[source][name]) == "function"
  end
  check(name .. " is registered in every source", present, name)
end

-- Every wrapper has to delegate to the component it replaced, not to a fixed
-- one: a source's own version of a component must survive being wrapped.
local function resolved(name, config)
  local out = registered.filesystem[name](config or {}, nil, nil)
  check(name .. " delegates to the component it wrapped", out.component == name, out.component)
  return out.config
end

-- Plain profile: private-use glyphs are replaced, the devicon provider is
-- removed outright rather than replaced since every glyph it returns is private
-- use, and standard Unicode is left alone.
do
  local git = resolved("git_status", { symbols = { modified = "GLYPH" } })
  check("plain is the default", git.symbols.modified == "M", git.symbols.modified)
  check("plain keeps the standard-unicode added mark", git.symbols.added == "✚", git.symbols.added)

  local icon = resolved("icon", { default = "GLYPH", folder_closed = "GLYPH", provider = echo("p") })
  check("plain drops the devicon provider", icon.provider == nil, tostring(icon.provider))
  check("plain replaces the folder icon", icon.folder_closed == "+", icon.folder_closed)
  check("plain blanks the file icon", icon.default == " ", "[" .. icon.default .. "]")

  local indent = resolved("indent", { expander_collapsed = "GLYPH", indent_marker = "│" })
  check("plain replaces the expander", indent.expander_collapsed == ">", indent.expander_collapsed)
  check("plain leaves the box-drawing indent marker", indent.indent_marker == "│", indent.indent_marker)
end

-- Glyph profile: everything neo-tree resolved passes through untouched.
maps["<leader>tg"]()
do
  local git = resolved("git_status", { symbols = { modified = "GLYPH" } })
  check("nerd passes the status symbols through", git.symbols.modified == "GLYPH", git.symbols.modified)

  local provider = echo("p")
  local icon = resolved("icon", { default = "GLYPH", folder_closed = "GLYPH", provider = provider })
  check("nerd keeps the devicon provider", icon.provider == provider, tostring(icon.provider))
  check("nerd keeps the folder icon", icon.folder_closed == "GLYPH", icon.folder_closed)

  local indent = resolved("indent", { expander_collapsed = "GLYPH" })
  check("nerd keeps the expander", indent.expander_collapsed == "GLYPH", indent.expander_collapsed)

  check("the toggle says which profile is active", notes[1] == "neo-tree glyphs: nerd", notes[1])
end

maps["<leader>tg"]()
do
  local git = resolved("git_status", { symbols = { modified = "GLYPH" } })
  check("a second toggle returns to plain", git.symbols.modified == "M", git.symbols.modified)
  check("toggling does not re-run setup", setup_calls == 1, setup_calls)
end

for _, want in ipairs({ "nerd", "plain", "nerd", "plain" }) do
  maps["<leader>tg"]()
  local git = registered.filesystem.git_status({ symbols = { modified = "GLYPH" } }, nil, nil).config
  local got = git.symbols.modified == "M" and "plain" or "nerd"
  if got ~= want then
    check("toggle stays in step (wanted " .. want .. ")", false, got)
    break
  end
end
check("toggling round-trips repeatedly", #notes == 6, #notes)

-- The whole point is terminals without a patched font, so the profile has to
-- cover every glyph neo-tree defaults to and stay 7-bit. The component only
-- ever echoes what it was handed, so the table in source is the only place the
-- full set can be checked.
local source_text = table.concat(vim.fn.readfile(here .. "/lua/plugins/neotree.lua"), "\n")
local profile = source_text:match("local plain_config = {(.-)\n}")
check("the plain profile exists in source", profile ~= nil)

local wanted = {
  "added",
  "conflict",
  "default",
  "deleted",
  "expander_collapsed",
  "expander_expanded",
  "folder_closed",
  "folder_empty",
  "folder_empty_open",
  "folder_open",
  "ignored",
  "modified",
  "renamed",
  "staged",
  "unstaged",
  "untracked",
}
local missing = {}
for _, key in ipairs(wanted) do
  if not profile:find(key .. " = ") then
    table.insert(missing, key)
  end
end
check("plain profile covers every private-use glyph key", #missing == 0, table.concat(missing, ","))

-- The invariant is not "7-bit" -- standard Unicode is deliberately kept -- but
-- that no private-use codepoint survives, since those are the ones a font
-- without a Nerd Font patch cannot draw.
local private = {}
for _, line in ipairs(vim.split(profile, "\n", { trimempty = true })) do
  local symbol = line:match('=%s*"(.*)",?$')
  for _, char in ipairs(symbol and vim.fn.split(symbol, "\\zs") or {}) do
    local cp = vim.fn.char2nr(char)
    if (cp >= 0xE000 and cp <= 0xF8FF) or (cp >= 0xF0000 and cp <= 0xFFFFD) then
      table.insert(private, line)
    end
  end
end
check("plain profile has no private-use codepoints", #private == 0, table.concat(private, " / "))

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
