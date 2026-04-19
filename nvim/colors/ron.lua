vim.opt.background = "dark"
vim.cmd.hi("clear")

if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "ron"

local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

hl("Normal", { fg = "#00ffff", bg = "#000000" })
hl("NonText", { fg = "#ffff00", bg = "#303030" })
hl("Comment", { fg = "#00ff00" })
hl("Constant", { fg = "#00ffff", bold = true })
hl("Identifier", { fg = "#00ffff" })
hl("Statement", { fg = "#add8e6" })
hl("PreProc", { fg = "#eea9b8" })
hl("Type", { fg = "#2e8b57", bold = true })
hl("Special", { fg = "#ffff00" })
hl("ErrorMsg", { fg = "#000000", bg = "#ff0000" })
hl("WarningMsg", { fg = "#000000", bg = "#00ff00" })
hl("Error", { bg = "#ff0000" })
hl("Todo", { fg = "#000000", bg = "#ffa500" })
hl("Cursor", { fg = "#00ff00", bg = "#60a060" })
hl("Search", { fg = "#000000", bg = "#a9a9a9", bold = true })
hl("IncSearch", { bg = "#4682b4" })
hl("LineNr", { fg = "#a9a9a9" })
hl("Title", { fg = "#a9a9a9" })
hl("ShowMarksHL", { fg = "#ffff00", bg = "#000000", bold = true })
hl("StatusLineNC", { fg = "#add8e6", bg = "#00008b" })
hl("StatusLine", { fg = "#00ffff", bg = "#0000ff", bold = true })
hl("Label", { fg = "#eec900" })
hl("Operator", { fg = "#ffa500" })
hl("Visual", { reverse = true })
hl("DiffChange", { bg = "#006400" })
hl("DiffText", { bg = "#6b8e23" })
hl("DiffAdd", { bg = "#6a5acd" })
hl("DiffDelete", { bg = "#ff7f50" })
hl("Folded", { bg = "#4d4d4d" })
hl("FoldColumn", { fg = "#ffffff", bg = "#4d4d4d" })
hl("cIf0", { fg = "#808080" })
hl("diffOnly", { fg = "#ff0000", bold = true })
