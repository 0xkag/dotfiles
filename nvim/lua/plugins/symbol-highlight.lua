local util = require("config.util")

local state = {
  start_pos = nil,
  base_pattern = nil,
  range = "buffer",
}

local ranges = { "buffer", "function" }

local function get_word_pattern()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    return nil
  end
  return "\\<" .. vim.fn.escape(word, [[/\]]) .. "\\>"
end

local function get_function_range()
  local ok, ts = pcall(vim.treesitter.get_node)
  if not ok or not ts then
    return nil
  end

  local node = ts
  while node do
    local type = node:type()
    if
      type:match("function")
      or type:match("method")
      or type == "function_definition"
      or type == "function_declaration"
      or type == "method_definition"
      or type == "method_declaration"
      or type == "func_literal"
    then
      local start_row = node:start()
      local end_row = node:end_()
      return start_row + 1, end_row + 1
    end
    node = node:parent()
  end
  return nil
end

local function apply_range()
  if not state.base_pattern then
    return
  end

  local pattern
  if state.range == "buffer" then
    pattern = state.base_pattern
  elseif state.range == "function" then
    local start_line, end_line = get_function_range()
    if start_line and end_line then
      pattern = "\\%>" .. (start_line - 1) .. "l\\%<" .. (end_line + 1) .. "l" .. state.base_pattern
    else
      pattern = state.base_pattern
    end
  end

  vim.fn.setreg("/", pattern)
  vim.opt.hlsearch = true
end

local function cycle_range()
  local idx = 1
  for i, r in ipairs(ranges) do
    if r == state.range then
      idx = i
      break
    end
  end
  state.range = ranges[(idx % #ranges) + 1]
  apply_range()
end

local function find_functions_with_symbol(symbol, direction)
  local bufnr = vim.api.nvim_get_current_buf()
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if not lang then
    return
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    return
  end

  local root = tree:root()
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
  local targets = {}

  local function walk(node)
    local type = node:type()
    local is_func = type:match("function")
      or type:match("method")
      or type == "func_literal"

    if is_func then
      local text = vim.treesitter.get_node_text(node, bufnr)
      if text and text:find(symbol, 1, true) then
        local row = node:start() + 1
        table.insert(targets, row)
      end
    end

    for child in node:iter_children() do
      walk(child)
    end
  end

  walk(root)
  table.sort(targets)

  if direction == 1 then
    for _, row in ipairs(targets) do
      if row > cursor_row then
        vim.api.nvim_win_set_cursor(0, { row, 0 })
        return
      end
    end
    if #targets > 0 then
      vim.api.nvim_win_set_cursor(0, { targets[1], 0 })
    end
  else
    for i = #targets, 1, -1 do
      if targets[i] < cursor_row then
        vim.api.nvim_win_set_cursor(0, { targets[i], 0 })
        return
      end
    end
    if #targets > 0 then
      vim.api.nvim_win_set_cursor(0, { targets[#targets], 0 })
    end
  end
end

local function on_enter()
  state.range = "buffer"
  vim.opt.hlsearch = true
end

local function on_exit()
  if state.base_pattern then
    vim.fn.setreg("/", state.base_pattern)
  end
end

return {
  "nvimtools/hydra.nvim",
  event = "VeryLazy",
  config = function()
    local Hydra = require("hydra")

    local symbol_hydra = Hydra({
      name = "Symbol Highlight",
      hint = "_n_ next  _N_/_p_ prev  _d_/_D_ def  _r_ range [%{range}]  _R_ reset  _e_ edit  _g_ goto  _/_ project  _z_ recenter",
      config = {
        color = "pink",
        invoke_on_body = false,
        hint = {
          type = "window",
          position = "bottom",
          float_opts = {
            border = "rounded",
          },
          funcs = {
            range = function()
              return state.range
            end,
          },
        },
        on_enter = on_enter,
        on_exit = on_exit,
      },
      mode = "n",
      heads = {
        { "n", "n", { desc = "next" } },
        { "N", "N", { desc = "prev" } },
        { "p", "N", { desc = "prev" } },
        {
          "d",
          function()
            local word = vim.fn.expand("<cword>")
            if state.base_pattern then
              word = state.base_pattern:gsub("\\<", ""):gsub("\\>", "")
            end
            find_functions_with_symbol(word, 1)
          end,
          { desc = "next def" },
        },
        {
          "D",
          function()
            local word = vim.fn.expand("<cword>")
            if state.base_pattern then
              word = state.base_pattern:gsub("\\<", ""):gsub("\\>", "")
            end
            find_functions_with_symbol(word, -1)
          end,
          { desc = "prev def" },
        },
        {
          "r",
          function()
            cycle_range()
          end,
          { desc = "range" },
        },
        {
          "R",
          function()
            if state.start_pos then
              vim.api.nvim_win_set_cursor(0, state.start_pos)
            end
          end,
          { desc = "reset" },
        },
        {
          "e",
          function()
            apply_range()
            require("multicursor-nvim").searchAllAddCursors()
          end,
          { exit = true, desc = "edit" },
        },
        {
          "g",
          function()
            vim.lsp.buf.definition()
          end,
          { exit = true, desc = "goto def" },
        },
        {
          "/",
          function()
            local word = vim.fn.expand("<cword>")
            if state.base_pattern then
              word = state.base_pattern:gsub("\\<", ""):gsub("\\>", "")
            end
            require("telescope.builtin").grep_string({ search = word })
          end,
          { exit = true, desc = "project" },
        },
        { "z", "zz", { desc = "recenter" } },
        { "q", nil, { exit = true, desc = "quit" } },
        { "<Esc>", nil, { exit = true, desc = "quit" } },
        { "<C-g>", nil, { exit = true, desc = "quit" } },
      },
    })

    local function enter_highlight()
      return function()
        local word = vim.fn.expand("<cword>")
        if word == "" then
          return
        end
        state.start_pos = vim.api.nvim_win_get_cursor(0)
        state.base_pattern = get_word_pattern()
        vim.fn.setreg("/", state.base_pattern)
        vim.opt.hlsearch = true
        symbol_hydra:activate()
      end
    end

    vim.keymap.set("n", "*", enter_highlight(), { desc = "Highlight symbol", silent = true })
    vim.keymap.set("n", "#", enter_highlight(), { desc = "Highlight symbol", silent = true })
    vim.keymap.set("n", "<leader>sh", function()
      local pattern = get_word_pattern()
      if not pattern then
        return
      end
      state.start_pos = vim.api.nvim_win_get_cursor(0)
      state.base_pattern = pattern
      vim.fn.setreg("/", pattern)
      vim.opt.hlsearch = true
      symbol_hydra:activate()
    end, { desc = "Symbol highlight" })

    vim.keymap.set("x", "*", function()
      util.search_visual(true)
    end, { desc = "Search selection forward", silent = true })
    vim.keymap.set("x", "#", function()
      util.search_visual(false)
    end, { desc = "Search selection backward", silent = true })
  end,
}
