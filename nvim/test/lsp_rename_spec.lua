-- Headless test for config.lsp_rename: the scoped rename behind <leader>cr
-- and ,rr.
-- Run: nvim/test/run.sh lsp_rename
--
-- Line, function and buffer scopes place multicursor cursors on every
-- whole-word match of the symbol under the cursor; the workspace scope goes
-- to inc-rename when its live preview is on, else to an LSP rename with a
-- count-and-confirm step. multicursor-nvim and the pickers are stubbed; the
-- cursor placement, the client choice and the routing are real.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/lsp_rename_spec.lua$", "")
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

local notices = {}
vim.notify = function(msg, level)
  table.insert(notices, { msg = msg, level = level })
end

-- A multicursor that records where cursors land.
local placed
package.preload["multicursor-nvim"] = function()
  return {
    action = function(fn)
      placed = { main = nil, added = {} }
      local function cursor(store)
        return {
          setPos = function(_, pos)
            store(pos)
          end,
        }
      end
      fn({
        mainCursor = function()
          return cursor(function(pos)
            placed.main = pos
          end)
        end,
        addCursor = function()
          return cursor(function(pos)
            table.insert(placed.added, pos)
          end)
        end,
      })
    end,
  }
end

local ok, rename = pcall(require, "config.lsp_rename")
check("config.lsp_rename loads", ok, rename)
if not ok then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
end

local function set_buf(lines, row, col)
  vim.cmd("enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row, col })
end

-- The client: pyright wins over pylsp for rename; otherwise the first that
-- offers it; none is nil.
do
  local original = vim.lsp.get_clients
  local clients = {}
  vim.lsp.get_clients = function()
    return clients
  end
  clients = { { name = "pylsp" }, { name = "pyright" } }
  check("pyright wins the rename", rename.pick_client(0).name == "pyright")
  clients = { { name = "ruff" }, { name = "pylsp" } }
  check("else the first provider", rename.pick_client(0).name == "ruff")
  clients = {}
  check("no provider is nil", rename.pick_client(0) == nil)
  vim.lsp.get_clients = original
end

-- Scopes: whole-word matches only, within the line, the buffer, or the
-- enclosing function.
do
  set_buf({ "foo = foo + food", "foo()" }, 1, 0)
  rename.multicursor("line")
  check("line scope: main cursor on the first match", vim.deep_equal(placed.main, { 1, 0 }), vim.inspect(placed))
  check("line scope: one more cursor, not on food", vim.deep_equal(placed.added, { { 1, 6 } }), vim.inspect(placed))

  set_buf({ "foo = foo + food", "foo()" }, 1, 0)
  rename.multicursor("buffer")
  check("buffer scope: reaches the second line", vim.deep_equal(placed.added, { { 1, 6 }, { 2, 0 } }), vim.inspect(placed))

  set_buf({ "  x" }, 1, 2)
  placed = nil
  notices = {}
  rename.multicursor("function")
  check("function scope without an enclosing function says so", placed == nil and notices[1] and notices[1].msg == "No enclosing function.", vim.inspect(notices))

  set_buf({ "" }, 1, 0)
  placed = nil
  notices = {}
  rename.multicursor("line")
  check("no symbol under the cursor says so", placed == nil and notices[1] and notices[1].msg == "No symbol under cursor.", vim.inspect(notices))
end

-- The dispatch menu routes by choice; the workspace route without a rename
-- provider says so instead of failing.
do
  local original_select = vim.ui.select
  local choice
  vim.ui.select = function(items, _, on_choice)
    for _, item in ipairs(items) do
      if item:find(choice, 1, true) then
        on_choice(item)
        return
      end
    end
    on_choice(nil)
  end
  set_buf({ "foo foo" }, 1, 0)
  choice = "Line"
  rename.dispatch()
  check("Line routes to the line scope", placed and vim.deep_equal(placed.added, { { 1, 4 } }), vim.inspect(placed))

  local original_input = vim.ui.input
  vim.ui.input = function(_, on_input)
    on_input("bar")
  end
  local original_clients = vim.lsp.get_clients
  vim.lsp.get_clients = function()
    return {}
  end
  vim.g.rename_inc_preview = false
  notices = {}
  choice = "Workspace"
  rename.dispatch()
  check("Workspace without a provider warns", notices[1] and notices[1].msg == "No LSP supports rename for this buffer." and notices[1].level == vim.log.levels.WARN, vim.inspect(notices))
  vim.ui.select, vim.ui.input, vim.lsp.get_clients = original_select, original_input, original_clients
end

-- The inc-rename preview toggle.
do
  vim.g.rename_inc_preview = true
  notices = {}
  rename.toggle_preview()
  check("toggle_preview turns the preview off", vim.g.rename_inc_preview == false and notices[1].msg:find("disabled") ~= nil, vim.inspect({ vim.g.rename_inc_preview, notices }))
  rename.toggle_preview()
  check("and on again", vim.g.rename_inc_preview == true and notices[2].msg:find("enabled") ~= nil, vim.inspect(notices))
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
