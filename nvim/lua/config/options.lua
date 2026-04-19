local opt = vim.opt
local tools = require("config.tools")

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.termguicolors = true
opt.splitbelow = true
opt.splitright = true
opt.scrolloff = 6
opt.sidescrolloff = 6
opt.signcolumn = "yes"
opt.cursorline = true
opt.wrap = false
opt.linebreak = false
opt.breakindent = true
opt.showbreak = "+++ "
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.autoindent = true
opt.shiftround = true
opt.updatetime = 200
opt.timeoutlen = 400
opt.completeopt = { "menu", "menuone", "noselect" }
opt.undofile = true
opt.backup = false
opt.writebackup = false
opt.confirm = true
opt.showmode = false
opt.pumheight = 12
opt.laststatus = 3
opt.colorcolumn = "80"
opt.virtualedit = "block"
opt.joinspaces = true
opt.autoread = true
opt.spelllang = { "en_us" }
opt.spellsuggest = "best,8"
opt.modeline = true
opt.wildmode = { "longest:full", "full" }
opt.list = true
opt.listchars = {
  eol = "¶",
  tab = "»·",
  nbsp = "_",
  extends = ">",
  precedes = "<",
}
opt.fillchars = {
  foldopen = "▾",
  foldclose = "▸",
  foldsep = " ",
}
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldenable = true
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.sessionoptions = {
  "buffers",
  "curdir",
  "folds",
  "help",
  "localoptions",
  "tabpages",
  "terminal",
  "winsize",
}

opt.shortmess:append("c")
opt.diffopt:append("linematch:60")

local dictionary = "/usr/share/dict/words"
if vim.fn.filereadable(dictionary) == 1 then
  opt.dictionary:append(dictionary)
end

-- Legacy Vim terminal tweak kept disabled for reference:
-- vim.o.t_BE = ""

if tools.available("rg") then
  opt.grepprg = "rg --vimgrep --smart-case --hidden"
  opt.grepformat = "%f:%l:%c:%m"
elseif tools.available("grep") then
  opt.grepprg = "grep -RIn"
  opt.grepformat = "%f:%l:%m"
end
