local M = {}

local modes = { "quiet", "manual", "full" }

M.state = {
  mode = vim.g.nvim_completion_mode or "quiet",
  delay_ms = tonumber(vim.g.nvim_completion_delay_ms) or 1000,
  signature_auto = vim.g.nvim_signature_auto == true,
}

local function valid_mode(mode)
  return mode == "quiet" or mode == "manual" or mode == "full"
end
M.valid_mode = valid_mode

local function notify_state()
  vim.notify(
    string.format(
      "Completion: %s%s; signature auto-popup: %s.",
      M.state.mode,
      M.state.mode == "quiet" and string.format(" (%dms delay)", M.state.delay_ms) or "",
      M.state.signature_auto and "on" or "off"
    ),
    vim.log.levels.INFO
  )
end

local function sources(cmp)
  return cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "path" },
  }, {
    { name = "buffer" },
  })
end

local function visible_selected(cmp)
  return cmp.visible() and cmp.get_selected_entry() ~= nil
end

function M.configure_cmp(cmp, luasnip)
  local quiet = M.state.mode == "quiet"
  local manual = M.state.mode == "manual"
  local full = M.state.mode == "full"

  cmp.setup({
    enabled = function()
      local buf = vim.api.nvim_get_current_buf()
      if vim.b[buf].cmp_disabled then
        return false
      end
      return vim.bo[buf].buftype ~= "prompt"
    end,
    preselect = cmp.PreselectMode.None,
    completion = {
      autocomplete = manual and false or { cmp.TriggerEvent.TextChanged },
      completeopt = "menu,menuone,noselect",
    },
    performance = {
      debounce = quiet and M.state.delay_ms or 60,
      throttle = quiet and math.min(M.state.delay_ms, 200) or 30,
    },
    experimental = {
      ghost_text = full,
    },
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
      ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
      ["<Down>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
      ["<Up>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
      ["<C-g>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.abort()
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<Esc>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.abort()
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<CR>"] = cmp.mapping(function(fallback)
        if visible_selected(cmp) then
          cmp.confirm({ select = false })
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if visible_selected(cmp) then
          cmp.confirm({ select = false })
        elseif cmp.visible() then
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
        elseif luasnip.expand_or_locally_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
        elseif luasnip.locally_jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { "i", "s" }),
    }),
    sources = sources(cmp),
    formatting = {
      fields = { "kind", "abbr", "menu" },
      format = function(entry, item)
        item.menu = ({
          nvim_lsp = "[LSP]",
          luasnip = "[Snip]",
          buffer = "[Buf]",
          path = "[Path]",
        })[entry.source.name] or ("[" .. entry.source.name .. "]")
        item.kind = string.format(" %s ", item.kind)
        return item
      end,
    },
    window = {
      completion = cmp.config.window.bordered({ border = "rounded" }),
      documentation = cmp.config.window.bordered({ border = "rounded" }),
    },
  })

  if manual then
    cmp.abort()
  end
end

function M.apply()
  local ok_cmp, cmp = pcall(require, "cmp")
  local ok_luasnip, luasnip = pcall(require, "luasnip")
  if ok_cmp and ok_luasnip then
    M.configure_cmp(cmp, luasnip)
  end
end

function M.set_mode(mode)
  if not valid_mode(mode) then
    vim.notify("Completion mode must be quiet, manual, or full.", vim.log.levels.WARN)
    return
  end

  M.state.mode = mode
  M.apply()
  notify_state()
end

function M.cycle_mode(include_full)
  local available = include_full and modes or { "quiet", "manual" }
  local idx = 1
  for i, mode in ipairs(available) do
    if mode == M.state.mode then
      idx = i
      break
    end
  end
  M.set_mode(available[(idx % #available) + 1])
end

function M.toggle_buffer()
  local buf = vim.api.nvim_get_current_buf()
  vim.b[buf].cmp_disabled = not vim.b[buf].cmp_disabled
  vim.notify(
    "Completion " .. (vim.b[buf].cmp_disabled and "disabled" or "enabled") .. " for this buffer.",
    vim.log.levels.INFO
  )
end

function M.set_delay(seconds)
  local parsed = tonumber(seconds)
  if not parsed or parsed < 0 then
    vim.notify("Completion delay expects a non-negative number of seconds.", vim.log.levels.WARN)
    return
  end

  M.state.delay_ms = math.floor(parsed * 1000)
  if M.state.mode == "quiet" then
    M.apply()
  end
  notify_state()
end

function M.toggle_signature_auto()
  M.state.signature_auto = not M.state.signature_auto
  notify_state()
end

function M.signature_auto_enabled()
  return M.state.signature_auto
end

function M.signature_float_opts()
  return {
    border = "rounded",
    close_events = { "CursorMoved", "CursorMovedI", "InsertCharPre", "BufHidden", "ModeChanged" },
    focusable = false,
  }
end

vim.api.nvim_create_user_command("NvimCompletionMode", function(command)
  if command.args == "" then
    notify_state()
    return
  end
  M.set_mode(command.args)
end, {
  complete = function()
    return modes
  end,
  desc = "Set Neovim completion mode",
  nargs = "?",
})

vim.api.nvim_create_user_command("NvimCompletionDelay", function(command)
  M.set_delay(command.args)
end, {
  desc = "Set quiet completion delay in seconds",
  nargs = 1,
})

vim.keymap.set("n", "<leader>ta", function()
  M.cycle_mode(false)
end, { desc = "Toggle auto-completion mode" })

vim.keymap.set("n", "<leader>tA", function()
  M.toggle_buffer()
end, { desc = "Auto-completion: toggle for buffer" })

vim.keymap.set("n", "<leader>tM", function()
  M.cycle_mode(true)
end, { desc = "Auto-completion: cycle mode" })

vim.keymap.set("n", "<leader>th", function()
  M.toggle_signature_auto()
end, { desc = "Toggle signature auto-popup" })

return M
