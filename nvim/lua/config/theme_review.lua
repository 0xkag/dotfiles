local M = {}

local function review_path(name)
  return vim.fs.joinpath(vim.fn.stdpath("config"), "theme-review", name)
end

function M.open()
  local files = {
    review_path("sample.py"),
    review_path("sample.md"),
    review_path("sample.diff"),
  }

  vim.cmd.tabnew(vim.fn.fnameescape(files[1]))
  vim.cmd.vsplit(vim.fn.fnameescape(files[2]))
  pcall(function()
    require("render-markdown").buf_disable()
  end)
  vim.cmd("wincmd h")
  vim.cmd("belowright split " .. vim.fn.fnameescape(files[3]))
  vim.cmd("wincmd t")

  vim.notify(table.concat({
    "Theme review opened.",
    "Try :colorscheme cyberdream, :colorscheme ron, and :colorscheme cyberpunk.",
    "Check comments, strings, headings, diff colors, line numbers, signcolumn, listchars, and colorcolumn.",
  }, "\n"), vim.log.levels.INFO, {
    title = "Theme Review",
  })
end

vim.api.nvim_create_user_command("ThemeReview", function()
  M.open()
end, {
  desc = "Open the theme review fixture",
})

return M
