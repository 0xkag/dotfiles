-- Git editor helpers for the gitrebase todo buffer and gitcommit message
-- buffer (standalone git as well as Neogit's in-session editors).
local M = {}

function M.gitrebase_move(dir)
  local cur = vim.fn.line(".")
  local last = vim.fn.line("$")
  if dir < 0 and cur > 1 then
    vim.cmd("move .-2") -- :move leaves the cursor on the moved line
  elseif dir > 0 and cur < last then
    vim.cmd("move .+1")
  end
end

function M.gitrebase_insert(directive, takes_arg)
  -- The built-in ftplugin only transforms commit lines; exec/break/label/reset/
  -- merge/update-ref are separate directives, so insert them on a new line below
  -- the current commit. Argument-taking ones leave the cursor in insert mode at
  -- end of line so the command/label/ref can be typed inline.
  local lnum = vim.fn.line(".")
  local text = takes_arg and (directive .. " ") or directive
  vim.fn.append(lnum, text)
  vim.api.nvim_win_set_cursor(0, { lnum + 1, #text })
  if takes_arg then
    vim.cmd("startinsert!")
  end
end

function M.gitrebase_show_commit()
  local line = vim.api.nvim_get_current_line()
  -- Todo lines look like "<cmd> <sha> <subject>"; ignore exec/break/blank/comments.
  local sha = line:match("^%s*%a+%s+(%x%x%x%x+)") or line:match("^%s*(%x%x%x%x+)")
  if not sha then
    vim.notify("No commit on this line", vim.log.levels.WARN)
    return
  end

  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local out = vim.fn.systemlist({ "git", "-C", dir, "show", "--stat", "-p", sha })
  if vim.v.shell_error ~= 0 then
    vim.notify("git show failed for " .. sha, vim.log.levels.ERROR)
    return
  end

  vim.cmd("botright vsplit")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].filetype = "git" -- built-in git syntax highlighting
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.keymap.set("n", "q", "<Cmd>close<CR>", {
    buffer = buf,
    desc = "Close",
    silent = true,
  })
end

function M.gitrebase_finish()
  vim.cmd("write")
  vim.cmd("qall") -- nvim must fully exit for git to proceed
end

function M.gitrebase_abort()
  vim.cmd("silent! %delete _") -- an empty todo list tells git to abort
  vim.cmd("write")
  vim.cmd("qall!")
end

function M.gitcommit_finish()
  -- Write + close the editor window. nvim exits when this is the last window
  -- (standalone `git commit`), or just closes the editor when Neogit opened it
  -- in-session, so we never qall an interactive session like the gitrebase helpers.
  vim.cmd("write")
  vim.cmd("quit")
end

function M.gitcommit_abort()
  vim.cmd("silent! %delete _") -- an empty message tells git to abort the commit
  vim.cmd("write")
  vim.cmd("quit")
end

return M
