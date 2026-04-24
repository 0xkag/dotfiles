vim.opt.background = "dark"
vim.cmd.hi("clear")

if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "cyberpunk"

local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

hl("Normal", { fg = "#d3d3d3", bg = "#000000" })
hl("Cursor", { fg = "#000000", bg = "#dcdccc" })
hl("CursorLine", { bg = "#333333" })
hl("CursorColumn", { bg = "#333333" })
hl("ColorColumn", { bg = "#383838" })
hl("LineNr", { fg = "#9fc59f", bg = "#000000" })
hl("CursorLineNr", { fg = "#ffffff", bg = "#000000", bold = true })
hl("SignColumn", { fg = "#dcdccc", bg = "#2b2b2b" })
hl("FoldColumn", { fg = "#dcdccc", bg = "#2b2b2b" })
hl("Folded", { fg = "#8b8989", bg = "#2b2b2b" })
hl("VertSplit", { fg = "#333333", bg = "#000000" })
hl("WinSeparator", { fg = "#333333", bg = "#000000" })

hl("StatusLine", { fg = "#4c83ff", bg = "#333333" })
hl("StatusLineNC", { fg = "#4d4d4d", bg = "#1a1a1a" })
hl("TabLine", { fg = "#4d4d4d", bg = "#1a1a1a" })
hl("TabLineFill", { bg = "#1a1a1a" })
hl("TabLineSel", { fg = "#4c83ff", bg = "#333333", bold = true })

hl("Pmenu", { fg = "#ffff00", bg = "#8b8989" })
hl("PmenuSel", { fg = "#000000", bg = "#ff1493" })
hl("PmenuSbar", { bg = "#333333" })
hl("PmenuThumb", { bg = "#000000" })

hl("Visual", { bg = "#7f073f" })
hl("VisualNOS", { bg = "#7f073f" })
hl("Search", { fg = "#000000", bg = "#ffff00" })
hl("IncSearch", { fg = "#000000", bg = "#ff1493" })
hl("CurSearch", { fg = "#000000", bg = "#ff1493", bold = true })
hl("Substitute", { fg = "#000000", bg = "#ff1493" })
hl("MatchParen", { fg = "#000000", bg = "#ff1493" })

hl("ErrorMsg", { fg = "#ff0000", bg = "#000000", bold = true })
hl("WarningMsg", { fg = "#ff69b4", bg = "#000000" })
hl("MoreMsg", { fg = "#61ce3c", bg = "#000000" })
hl("ModeMsg", { fg = "#4c83ff", bold = true })
hl("Question", { fg = "#61ce3c", bg = "#000000" })
hl("Title", { fg = "#ff1493", bold = true })

hl("DiffAdd", { fg = "#00ff00" })
hl("DiffChange", { fg = "#ffff00" })
hl("DiffDelete", { fg = "#ff0000" })
hl("DiffText", { fg = "#ffff00", bg = "#4f4f4f", bold = true })

hl("SpellBad", { sp = "#ff6400", undercurl = true })
hl("SpellCap", { sp = "#fbde2d", undercurl = true })
hl("SpellRare", { sp = "#7b68ee", undercurl = true })
hl("SpellLocal", { sp = "#61ce3c", undercurl = true })

hl("Comment", { fg = "#8b8989", italic = true })
hl("Constant", { fg = "#96cbfe" })
hl("String", { fg = "#61ce3c" })
hl("Character", { fg = "#61ce3c" })
hl("Number", { fg = "#96cbfe" })
hl("Boolean", { fg = "#96cbfe" })
hl("Float", { fg = "#96cbfe" })
hl("Identifier", { fg = "#ff69b4" })
hl("Function", { fg = "#ff1493" })
hl("Statement", { fg = "#4c83ff" })
hl("Conditional", { fg = "#4c83ff" })
hl("Repeat", { fg = "#4c83ff" })
hl("Label", { fg = "#4c83ff" })
hl("Operator", { fg = "#00ffff" })
hl("Keyword", { fg = "#4c83ff" })
hl("Exception", { fg = "#4c83ff" })
hl("PreProc", { fg = "#919191" })
hl("Include", { fg = "#919191" })
hl("Define", { fg = "#919191" })
hl("Macro", { fg = "#919191" })
hl("PreCondit", { fg = "#919191" })
hl("Type", { fg = "#afd8af" })
hl("StorageClass", { fg = "#afd8af" })
hl("Structure", { fg = "#afd8af" })
hl("Typedef", { fg = "#afd8af" })
hl("Special", { fg = "#4c83ff" })
hl("SpecialChar", { fg = "#e9c062" })
hl("Tag", { fg = "#ff1493" })
hl("Delimiter", { fg = "#dcdccc" })
hl("SpecialComment", { fg = "#fbde2d" })
hl("Debug", { fg = "#dca3a3" })
hl("Underlined", { fg = "#ffff00", underline = true })
hl("Ignore", { fg = "#6f6f6f" })
hl("Error", { fg = "#ff0000", bg = "#000000", bold = true, underline = true })
hl("Todo", { fg = "#ffa500", bg = "#000000", bold = true })

hl("NonText", { fg = "#4f4f4f" })
hl("SpecialKey", { fg = "#4f4f4f" })
hl("Conceal", { fg = "#add8e6" })
hl("Directory", { fg = "#94bff3", bold = true })
hl("WildMenu", { fg = "#61ce3c", bg = "#000000" })

vim.g.terminal_color_0 = "#000000"
vim.g.terminal_color_1 = "#8b0000"
vim.g.terminal_color_2 = "#00ff00"
vim.g.terminal_color_3 = "#ffa500"
vim.g.terminal_color_4 = "#7b68ee"
vim.g.terminal_color_5 = "#dc8cc3"
vim.g.terminal_color_6 = "#93e0e3"
vim.g.terminal_color_7 = "#dcdccc"
vim.g.terminal_color_8 = "#4f4f4f"
vim.g.terminal_color_9 = "#ff0000"
vim.g.terminal_color_10 = "#61ce3c"
vim.g.terminal_color_11 = "#ffff00"
vim.g.terminal_color_12 = "#4c83ff"
vim.g.terminal_color_13 = "#ff69b4"
vim.g.terminal_color_14 = "#00ffff"
vim.g.terminal_color_15 = "#ffffff"
