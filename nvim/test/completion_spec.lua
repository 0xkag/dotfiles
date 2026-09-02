-- Headless test harness for config.completion mode state machine.
-- Run: nvim --headless -u NONE -l nvim/test/completion_spec.lua
--
-- The pure mode logic (valid_mode, cycle_mode, set_mode, toggle_buffer,
-- set_delay) and configure_cmp(), driven through a fake cmp table that records
-- what setup() was handed; apply() is a no-op when cmp is absent.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/completion_spec.lua$", "")
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

-- Silence the INFO/WARN notifications the mode setters emit so spec output is
-- just the ok/FAIL lines.
vim.notify = function() end

local completion = require("config.completion")

-- valid_mode(): exactly the three known modes.
check("valid_mode quiet", completion.valid_mode("quiet") == true)
check("valid_mode manual", completion.valid_mode("manual") == true)
check("valid_mode full", completion.valid_mode("full") == true)
check("valid_mode rejects junk", completion.valid_mode("loud") == false, completion.valid_mode("loud"))
check("valid_mode rejects nil", completion.valid_mode(nil) == false)

-- set_mode(): valid modes stick; invalid ones leave state unchanged.
completion.set_mode("manual")
check("set_mode manual sticks", completion.state.mode == "manual", completion.state.mode)
completion.set_mode("bogus")
check("set_mode ignores invalid", completion.state.mode == "manual", completion.state.mode)

-- cycle_mode(false): two-way quiet <-> manual, never reaches full.
completion.set_mode("quiet")
completion.cycle_mode(false)
check("cycle(false) quiet -> manual", completion.state.mode == "manual", completion.state.mode)
completion.cycle_mode(false)
check("cycle(false) manual -> quiet", completion.state.mode == "quiet", completion.state.mode)
-- From a mode outside the 2-cycle (full), cycle_mode(false) treats the current
-- mode as index 1 and advances to the second entry (manual).
completion.set_mode("full")
completion.cycle_mode(false)
check("cycle(false) from full -> manual", completion.state.mode == "manual", completion.state.mode)

-- cycle_mode(true): three-way quiet -> manual -> full -> quiet.
completion.set_mode("quiet")
completion.cycle_mode(true)
check("cycle(true) quiet -> manual", completion.state.mode == "manual", completion.state.mode)
completion.cycle_mode(true)
check("cycle(true) manual -> full", completion.state.mode == "full", completion.state.mode)
completion.cycle_mode(true)
check("cycle(true) full -> quiet", completion.state.mode == "quiet", completion.state.mode)

-- toggle_buffer(): flips the per-buffer cmp_disabled flag.
local buf = vim.api.nvim_get_current_buf()
vim.b[buf].cmp_disabled = nil
completion.toggle_buffer()
check("toggle_buffer disables", vim.b[buf].cmp_disabled == true, vim.b[buf].cmp_disabled)
completion.toggle_buffer()
check("toggle_buffer re-enables", vim.b[buf].cmp_disabled == false, vim.b[buf].cmp_disabled)

-- set_delay(): seconds -> ms; rejects negatives/non-numbers.
completion.set_delay(1.5)
check("set_delay 1.5s -> 1500ms", completion.state.delay_ms == 1500, completion.state.delay_ms)
completion.set_delay(-1)
check("set_delay rejects negative", completion.state.delay_ms == 1500, completion.state.delay_ms)
completion.set_delay("notanumber")
check("set_delay rejects non-number", completion.state.delay_ms == 1500, completion.state.delay_ms)

-- configure_cmp(): what each mode asks of cmp. The fake cmp records the setup
-- table and the calls the mappings make, and the enum tables mirror cmp's.
do
  local captured, calls = nil, {}
  local visible, selected = false, false
  local function record(name)
    return function(...)
      table.insert(calls, name)
      return name
    end
  end
  local cmp = {
    PreselectMode = { None = "none" },
    SelectBehavior = { Select = "select" },
    TriggerEvent = { TextChanged = "TextChanged" },
    abort = record("abort"),
    confirm = record("confirm"),
    config = {
      sources = function(primary, fallback)
        return { primary = primary, fallback = fallback }
      end,
      window = {
        bordered = function(opts)
          return opts
        end,
      },
    },
    get_selected_entry = function()
      return selected and {} or nil
    end,
    select_next_item = record("select_next_item"),
    select_prev_item = record("select_prev_item"),
    mapping = setmetatable({
      complete = record("complete"),
      preset = {
        insert = function(maps)
          return maps
        end,
      },
      select_next_item = record("select_next_item"),
      select_prev_item = record("select_prev_item"),
    }, {
      __call = function(_, fn, modes)
        return { fn = fn, modes = modes }
      end,
    }),
    setup = function(opts)
      captured = opts
    end,
    visible = function()
      return visible
    end,
  }
  local luasnip = {
    expand_or_jump = record("expand_or_jump"),
    expand_or_locally_jumpable = function()
      return false
    end,
    jump = record("jump"),
    locally_jumpable = function()
      return false
    end,
    lsp_expand = record("lsp_expand"),
  }
  local function fallback()
    table.insert(calls, "fallback")
  end

  -- Quiet: completion still fires on typing, but debounced by the delay, and
  -- with no ghost text.
  completion.set_mode("quiet")
  completion.set_delay(1.5)
  calls = {}
  completion.configure_cmp(cmp, luasnip)
  check("quiet completes on TextChanged", vim.deep_equal(captured.completion.autocomplete, { "TextChanged" }), vim.inspect(captured.completion.autocomplete))
  check("quiet debounces by the delay", captured.performance.debounce == 1500, captured.performance.debounce)
  check("quiet throttles to at most 200 ms", captured.performance.throttle == 200, captured.performance.throttle)
  check("quiet shows no ghost text", captured.experimental.ghost_text == false, captured.experimental.ghost_text)
  check("nothing is preselected", captured.preselect == "none", captured.preselect)
  check("quiet does not abort an open menu", not vim.list_contains(calls, "abort"), vim.inspect(calls))

  -- Manual: nothing fires on typing, and an open menu is closed on the switch.
  completion.set_mode("manual")
  calls = {}
  completion.configure_cmp(cmp, luasnip)
  check("manual never autocompletes", captured.completion.autocomplete == false, vim.inspect(captured.completion.autocomplete))
  check("manual uses the short debounce", captured.performance.debounce == 60 and captured.performance.throttle == 30, vim.inspect(captured.performance))
  check("switching to manual aborts the menu", vim.list_contains(calls, "abort"), vim.inspect(calls))

  -- Full: typing completes at once, with ghost text.
  completion.set_mode("full")
  completion.configure_cmp(cmp, luasnip)
  check("full completes on TextChanged", vim.deep_equal(captured.completion.autocomplete, { "TextChanged" }), vim.inspect(captured.completion.autocomplete))
  check("full shows ghost text", captured.experimental.ghost_text == true, captured.experimental.ghost_text)
  check("full uses the short debounce", captured.performance.debounce == 60, captured.performance.debounce)

  -- Shared by every mode.
  check("LSP, snippets and paths come before buffer words", vim.deep_equal(vim.tbl_map(function(s)
    return s.name
  end, captured.sources.primary), { "nvim_lsp", "luasnip", "path" }) and captured.sources.fallback[1].name == "buffer", vim.inspect(captured.sources))
  check("the menu names the source", captured.formatting.format({ source = { name = "nvim_lsp" } }, { kind = "Text" }).menu == "[LSP]")
  check("an unknown source is bracketed", captured.formatting.format({ source = { name = "odd" } }, { kind = "Text" }).menu == "[odd]")
  check("the windows are bordered", captured.window.completion.border == "rounded" and captured.window.documentation.border == "rounded", vim.inspect(captured.window))
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(scratch)
  check("enabled in an ordinary buffer", captured.enabled() == true)
  vim.b[scratch].cmp_disabled = true
  check("disabled where toggle_buffer turned it off", captured.enabled() == false)
  vim.b[scratch].cmp_disabled = false
  vim.bo[scratch].buftype = "prompt"
  check("disabled in a prompt buffer", captured.enabled() == false)
  vim.bo[scratch].buftype = ""

  -- <CR> confirms only an explicitly selected item; <Tab> confirms a selected
  -- one, moves through the menu, jumps a snippet, and otherwise falls through.
  local cr, tab = captured.mapping["<CR>"].fn, captured.mapping["<Tab>"].fn
  calls, visible, selected = {}, false, false
  cr(fallback)
  check("<CR> with no menu falls through", vim.deep_equal(calls, { "fallback" }), vim.inspect(calls))
  calls, visible, selected = {}, true, false
  cr(fallback)
  check("<CR> with a menu but no selection falls through", vim.deep_equal(calls, { "fallback" }), vim.inspect(calls))
  calls, visible, selected = {}, true, true
  cr(fallback)
  check("<CR> confirms a selected item", vim.deep_equal(calls, { "confirm" }), vim.inspect(calls))
  calls, visible, selected = {}, true, false
  tab(fallback)
  check("<Tab> moves through an open menu", vim.deep_equal(calls, { "select_next_item" }), vim.inspect(calls))
  calls, visible, selected = {}, true, true
  tab(fallback)
  check("<Tab> confirms a selected item", vim.deep_equal(calls, { "confirm" }), vim.inspect(calls))
  calls, visible, selected = {}, false, false
  luasnip.expand_or_locally_jumpable = function()
    return true
  end
  tab(fallback)
  check("<Tab> jumps a snippet when there is one", vim.deep_equal(calls, { "expand_or_jump" }), vim.inspect(calls))
  luasnip.expand_or_locally_jumpable = function()
    return false
  end
  calls = {}
  tab(fallback)
  check("<Tab> otherwise falls through", vim.deep_equal(calls, { "fallback" }), vim.inspect(calls))
  check("<CR> and <Tab> work in insert and snippet modes", vim.deep_equal(captured.mapping["<CR>"].modes, { "i", "s" }) and vim.deep_equal(captured.mapping["<Tab>"].modes, { "i", "s" }), vim.inspect(captured.mapping["<CR>"].modes))
  completion.set_mode("quiet")
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
