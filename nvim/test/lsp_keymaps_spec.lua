-- Headless test for config.lsp_keymaps: the global LSP keys and the
-- per-buffer set every LspAttach installs.
-- Run: nvim/test/run.sh lsp_keymaps
--
-- These lived in plugins/lsp.lua's config closure, which no spec could load,
-- so keymaps_spec used to read that file's source to check what it did not
-- map. Now the handler runs against a fake client: telescope's builtin is a
-- stub, the LSP functions are Neovim's own and are only mapped, not called.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/lsp_keymaps_spec.lua$", "")
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
package.preload["telescope.builtin"] = function()
  return setmetatable({}, {
    __index = function()
      return function() end
    end,
  })
end

local ok, keymaps = pcall(require, "config.lsp_keymaps")
check("config.lsp_keymaps loads", ok, keymaps)
if not ok then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
end

local function buffer_map(lhs, mode)
  return vim.fn.maparg(lhs, mode or "n", false, true)
end

-- setup(): the global diagnostic keys, the inc-rename toggle, and the
-- LspAttach handler.
do
  keymaps.setup()
  for _, lhs in ipairs({ "<leader>ex", "<leader>en", "<leader>ep", "<leader>ec", "<leader>tR" }) do
    local m = buffer_map(lhs)
    check(lhs .. " is a global map with a desc", m.buffer == 0 and (m.desc or "") ~= "", vim.inspect(m))
  end
  local attach = vim.api.nvim_get_autocmds({ event = "LspAttach" })
  check("an LspAttach handler is registered", #attach >= 1, #attach)
end

-- attach(): the buffer set for a client without signature help.
do
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  keymaps.attach(buf, { server_capabilities = {} })

  for _, lhs in ipairs({ "gd", "gr", "K", "<leader>ca", "<leader>cr", "<localleader>gg", "<localleader>gd", "<localleader>rr", "<localleader>=q", "<localleader>br", "<leader>ch", "<localleader>Tl" }) do
    check(lhs .. " is mapped in the buffer", buffer_map(lhs).buffer == 1, vim.inspect(buffer_map(lhs)))
  end
  check(",=q is also a visual map", buffer_map("<localleader>=q", "x").buffer == 1)
  check(",=r is a visual map", buffer_map("<localleader>=r", "x").buffer == 1)
  check("K is the config's hover, not the default", buffer_map("K").desc == "Hover", vim.inspect(buffer_map("K")))
  check("<C-k> opens signature help in insert mode too", buffer_map("<C-k>", "i").buffer == 1)

  -- Neovim's own maps are not restated, and the keys retired on 2026-09-02
  -- stay retired.
  for _, lhs in ipairs({ "[d", "]d", "<localleader>gA", "<localleader>gR", "<localleader>gS", "<localleader>gt" }) do
    check(lhs .. " is not mapped in the buffer", buffer_map(lhs).buffer ~= 1, vim.inspect(buffer_map(lhs)))
  end
  check("no signature template keys without signature help", buffer_map("<localleader>ia").buffer ~= 1)

  local undescribed = {}
  for _, mode in ipairs({ "n", "x", "i" }) do
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      if not m.desc or m.desc == "" then
        table.insert(undescribed, mode .. " " .. m.lhs)
      end
    end
  end
  check("every buffer map has a desc", #undescribed == 0, table.concat(undescribed, ", "))
end

-- attach() with signature help adds the template keys through lsp_signature.
do
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  keymaps.attach(buf, { server_capabilities = { signatureHelpProvider = {} }, offset_encoding = "utf-16" })
  check(",ia is mapped when the server offers signatures", buffer_map("<localleader>ia").buffer == 1)
  check(",ik is mapped when the server offers signatures", buffer_map("<localleader>ik").buffer == 1)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
