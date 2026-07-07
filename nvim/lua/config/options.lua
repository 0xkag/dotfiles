local opt = vim.opt
local tools = require("config.tools")

opt.number = true
opt.relativenumber = true
opt.background = "dark"
opt.lazyredraw = true
opt.mouse = "a"

-- Clipboard tristate.  Default 'full' = unnamedplus (system clipboard).
-- 'tmux' = custom provider that pipes "+ writes to `tmux load-buffer -`
-- so yanks reach tmux's buffer but not the system clipboard.
-- 'off'  = clipboard option cleared; "+y populates only nvim's internal
-- + register.
-- Toggle via :ClipMode {full|tmux|off} or <leader>tC (see keymaps.lua).
vim.g.nvim_clipboard_mode = vim.g.nvim_clipboard_mode or "full"

local function apply_clipboard_mode(mode)
  if mode == "off" then
    opt.clipboard = ""
    vim.g.clipboard = nil
  elseif mode == "tmux" then
    opt.clipboard = "unnamedplus"
    vim.g.clipboard = {
      name = "tmux-only",
      copy = {
        ["+"] = { "tmux", "load-buffer", "-" },
        ["*"] = { "tmux", "load-buffer", "-" },
      },
      paste = {
        ["+"] = { "tmux", "save-buffer", "-" },
        ["*"] = { "tmux", "save-buffer", "-" },
      },
      cache_enabled = 0,
    }
  else
    opt.clipboard = "unnamedplus"
    vim.g.clipboard = nil  -- let nvim auto-detect (pbcopy/wl-copy/xclip/etc.)
  end
end
_G.NvimClipMode = {
  apply = apply_clipboard_mode,
  cycle = function()
    local cur = vim.g.nvim_clipboard_mode or "full"
    local nxt = cur == "full" and "tmux" or cur == "tmux" and "off" or "full"
    vim.g.nvim_clipboard_mode = nxt
    apply_clipboard_mode(nxt)
    vim.notify("clipboard: " .. nxt, vim.log.levels.INFO)
  end,
  set = function(mode)
    if mode ~= "full" and mode ~= "tmux" and mode ~= "off" then
      vim.notify("ClipMode: invalid (full|tmux|off)", vim.log.levels.ERROR)
      return
    end
    vim.g.nvim_clipboard_mode = mode
    apply_clipboard_mode(mode)
    vim.notify("clipboard: " .. mode, vim.log.levels.INFO)
  end,
  toggle_off = function()
    local cur = vim.g.nvim_clipboard_mode or "full"
    local nxt = cur == "off" and "full" or "off"
    vim.g.nvim_clipboard_mode = nxt
    apply_clipboard_mode(nxt)
    vim.notify("clipboard: " .. nxt, vim.log.levels.INFO)
  end,
}
apply_clipboard_mode(vim.g.nvim_clipboard_mode)

vim.api.nvim_create_user_command("ClipMode", function(args)
  _G.NvimClipMode.set(args.args)
end, {
  nargs = 1,
  complete = function() return { "full", "tmux", "off" } end,
})
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
opt.showmatch = true
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.autoindent = true
opt.shiftround = true
opt.textwidth = 78
opt.updatetime = 200
opt.timeoutlen = 500
opt.ttimeout = true
opt.ttimeoutlen = 10
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
opt.wildmenu = true
opt.wildmode = { "longest:full", "full" }
opt.wildoptions = { "tagfile" }
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
vim.cmd("set formatoptions+=c")
vim.cmd("set formatoptions+=l")
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
opt.diffopt:append("inline:word")

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
