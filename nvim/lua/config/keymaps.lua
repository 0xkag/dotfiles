-- ~/.config/nvim/lua/config/keymaps.lua

local map = vim.keymap.set
local util = require("config.util")

local function toggle_window_option(name)
  vim.wo[name] = not vim.wo[name]
end

local function edit_path(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

map("i", "fd", "<Esc>", { desc = "Escape insert", silent = true })
map("c", "<C-a>", "<Home>", { desc = "Cmdline start", silent = true })
map("c", "<C-e>", "<End>", { desc = "Cmdline end", silent = true })
map("i", "<C-a>", "<Home>", { desc = "Line start", silent = true })
map("i", "<C-e>", "<End>", { desc = "Line end", silent = true })
map("i", "<C-w>", "<C-o>daW", { desc = "Delete word forward", silent = true })
map("i", "<C-h>", "<C-o>h", { desc = "Cursor left", silent = true })
map("i", "<C-l>", "<C-o>l", { desc = "Cursor right", silent = true })
map("n", "<C-a>", "<Home>", { desc = "Line start", silent = true })
map("n", "<C-e>", "<End>", { desc = "Line end", silent = true })
map("n", "Y", "y$", { desc = "Yank to end of line", silent = true })
map("n", "gV", "`[v`]", { desc = "Select last changed text", silent = true })

map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
map("n", "0", "g0", { silent = true })
map("n", "^", "g^", { silent = true })
map("n", "$", "g$", { silent = true })

map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move lines down", silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move lines up", silent = true })
map("x", ".", ":normal .<CR>", { desc = "Repeat over selection", silent = true })

map({ "n", "t" }, "<C-h>", "<Cmd>wincmd h<CR>", { silent = true })
map({ "n", "t" }, "<C-j>", "<Cmd>wincmd j<CR>", { silent = true })
map({ "n", "t" }, "<C-k>", "<Cmd>wincmd k<CR>", { silent = true })
map({ "n", "t" }, "<C-l>", "<Cmd>wincmd l<CR>", { silent = true })
map("t", "<Esc>", [[<C-\><C-n>]], { desc = "Terminal normal mode", silent = true })
map("t", "<C-w>", [[<C-\><C-n><C-w>]], { silent = true })

map("n", "<C-x><C-s>", "<Cmd>write<CR>", { desc = "Save file", silent = true })
map("i", "<C-x><C-s>", "<C-o>:write<CR>", { desc = "Save file", silent = true })

map("n", "<leader>fs", "<Cmd>write<CR>", { desc = "Save file", silent = true })
map("n", "<leader>fS", "<Cmd>wall<CR>", { desc = "Save all files", silent = true })
map("n", "<leader>fev", function()
  edit_path(vim.fs.joinpath(vim.env.HOME, ".dotfiles", "nvim", "init.lua"))
end, { desc = "Edit init.lua", silent = true })
map("n", "<leader>fed", util.dotfiles, { desc = "Edit dotfiles", silent = true })

map("n", "<leader>bn", "<Cmd>bnext<CR>", { desc = "Next buffer", silent = true })
map("n", "<leader>bp", "<Cmd>bprevious<CR>", { desc = "Previous buffer", silent = true })
map("n", "<leader><Tab>", "<C-^>", { desc = "Alternate buffer", silent = true })
map("n", "<leader>bd", function()
  require("mini.bufremove").delete(0, false)
end, { desc = "Delete buffer" })
map("n", "<leader>bD", function()
  require("mini.bufremove").delete(0, true)
end, { desc = "Delete buffer force" })

map("n", "<leader>h", "<Cmd>nohlsearch<CR>", { desc = "Clear search highlight", silent = true })
map("n", "g!", util.squeeze_spaces_line, { desc = "Squeeze spaces" })
map("x", "g!", util.squeeze_spaces_visual, { desc = "Squeeze spaces" })
map("x", "*", function()
  util.search_visual(true)
end, { desc = "Search selection forward", silent = true })
map("x", "#", function()
  util.search_visual(false)
end, { desc = "Search selection backward", silent = true })
map("x", "<leader>%", util.substitute_visual, { desc = "Replace selection in buffer", silent = true })
map("n", "<localleader>gg", util.global_definitions, { desc = "Go to definition", silent = true })
map("n", "<localleader>gr", util.global_references, { desc = "References", silent = true })
map("n", "<localleader>gs", util.global_prompt, { desc = "Project symbols", silent = true })
map("n", "<localleader>gb", "<C-o>", { desc = "Jump back", silent = true })
map("n", "gd", util.global_definitions, { desc = "Global definitions", silent = true })
map("n", "gr", util.global_references, { desc = "Global references", silent = true })
map("n", "<leader>cg", util.global_prompt, { desc = "Global symbol search", silent = true })
map("n", "<leader>cm", "<Cmd>NvimDeps current<CR>", { desc = "Missing dependencies", silent = true })
map("n", "<leader>cM", "<Cmd>NvimDeps<CR>", { desc = "All missing dependencies", silent = true })
map("n", "<leader>cp", "<Cmd>PyenvInfo<CR>", { desc = "Python environment", silent = true })
map("n", "<leader>pu", util.global_update, { desc = "Update GNU Global tags", silent = true })

map({ "n", "x" }, "<leader>yy", '"+y', { desc = "Yank to clipboard" })
map({ "n", "x" }, "<leader>C", '"+y', { desc = "Yank to clipboard (legacy)" })
map("n", "<leader>Y", '"+y$', { desc = "Yank to EOL (legacy)", silent = true })
map("n", "<leader>yY", '"+yy', { desc = "Yank line to clipboard" })
map({ "n", "x" }, "<leader>yp", '"+p', { desc = "Paste after" })
map({ "n", "x" }, "<leader>yP", '"+P', { desc = "Paste before" })
map("n", "<leader><space>", '"+yy', { desc = "Copy current line" })
map("x", "<leader><space>", '"+y', { desc = "Copy selection" })

-- Disabled Vim-era clipboard fallback for hosts without unnamedplus/clipboard:
-- map("x", "<leader>yy", "<Cmd>w !clip-in<CR>", { desc = "Yank to clipboard fallback", silent = true })
-- map("n", "<leader>yY", "<Cmd>.w !clip-in<CR>", { desc = "Yank line to clipboard fallback", silent = true })
-- map("n", "<leader>yp", "<Cmd>r !clip-out<CR>", { desc = "Paste after fallback", silent = true })
-- map("n", "<leader>yP", "<Cmd>.-1r !clip-out<CR>", { desc = "Paste before fallback", silent = true })

map("n", "<leader>wv", "<C-w>v", { desc = "Vertical split" })
map("n", "<leader>ws", "<C-w>s", { desc = "Horizontal split" })
map("n", "<leader>w/", "<C-w>v", { desc = "Vertical split", silent = true })
map("n", "<leader>w-", "<C-w>s", { desc = "Horizontal split", silent = true })
map("n", "<leader>wd", "<Cmd>close<CR>", { desc = "Close window", silent = true })
map("n", "<leader>wo", "<Cmd>only<CR>", { desc = "Only window", silent = true })
map("n", "<leader>w=", "<C-w>=", { desc = "Balance windows" })
map("n", "<leader>wm", "<Cmd>wincmd _<Bar>wincmd |<CR>", { desc = "Maximize window", silent = true })
map("n", "<leader>wh", "<Cmd>wincmd h<CR>", { desc = "Window left", silent = true })
map("n", "<leader>wj", "<Cmd>wincmd j<CR>", { desc = "Window down", silent = true })
map("n", "<leader>wk", "<Cmd>wincmd k<CR>", { desc = "Window up", silent = true })
map("n", "<leader>wl", "<Cmd>wincmd l<CR>", { desc = "Window right", silent = true })

map("n", "<leader>tn", function()
  if vim.wo.number and vim.wo.relativenumber then
    vim.wo.relativenumber = false
  elseif vim.wo.number then
    vim.wo.number = false
  else
    vim.wo.number = true
    vim.wo.relativenumber = true
  end
end, { desc = "Cycle line numbers" })
map("n", "<leader>tr", function()
  toggle_window_option("relativenumber")
end, { desc = "Relative numbers" })
map("n", "<leader>tw", function()
  toggle_window_option("wrap")
  vim.wo.linebreak = vim.wo.wrap
end, { desc = "Wrap lines" })
map("n", "<leader>ts", function()
  toggle_window_option("spell")
end, { desc = "Spell check" })
map("n", "<leader>tl", function()
  toggle_window_option("list")
end, { desc = "List characters" })
map("n", "<leader>tvt", function()
  toggle_window_option("list")
end, { desc = "List characters", silent = true })
map("n", "<leader>tva", util.listchars_ascii, { desc = "ASCII listchars", silent = true })
map("n", "<leader>tvu", util.listchars_unicode, { desc = "Unicode listchars", silent = true })
map("n", "<leader>tc", function()
  local enabled = not (vim.wo.cursorline and vim.wo.cursorcolumn)
  vim.wo.cursorline = enabled
  vim.wo.cursorcolumn = enabled
end, { desc = "Cursor guides" })

map("n", "<leader>qq", "<Cmd>quit<CR>", { desc = "Quit window", silent = true })
map("n", "<leader>qQ", "<Cmd>qa<CR>", { desc = "Quit all", silent = true })
map("n", "<leader>qw", "<Cmd>wq<CR>", { desc = "Save and quit", silent = true })
