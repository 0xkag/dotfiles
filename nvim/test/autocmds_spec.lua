-- Headless test harness for config.autocmds FileType behavior.
-- Run: nvim --headless -u NONE -l nvim/test/autocmds_spec.lua
--
-- Guards the gitcommit/gitrebase formatting autocmd. The built-in gitcommit
-- ftplugin sets `formatoptions+=tl`; the `l` flag suppresses auto-wrap on lines
-- that were already longer than textwidth when insert started, which makes
-- textwidth look ignored when amending a commit (the body is pre-filled with
-- long lines). The autocmd must set textwidth=75 AND drop `l` so amended bodies
-- reflow. This spec exists because that fix has regressed repeatedly.
local here = debug.getinfo(1, "S").source:sub(2):gsub("/test/autocmds_spec.lua$", "")
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

-- Enable the built-in ftplugins so the gitcommit ftplugin (formatoptions+=tl)
-- runs on FileType, exactly as it does in a real `git commit` session. Require
-- the module afterwards so its FileType autocmd registers -- and therefore
-- fires -- after the built-in ftplugin.
vim.cmd("filetype plugin on")
require("config.autocmds")

-- Drive a real FileType event the way `git commit` / `git commit --amend` do.
local function open_as(filetype)
  vim.cmd("enew")
  vim.bo.filetype = filetype
  return vim.api.nvim_get_current_buf()
end

-- gitcommit: textwidth is 75 and the `l` flag is gone so amended (long
-- pre-existing) body lines still reflow.
open_as("gitcommit")
check("gitcommit textwidth is 75", vim.bo.textwidth == 75, vim.bo.textwidth)
check(
  "gitcommit formatoptions drops l",
  not vim.bo.formatoptions:find("l"),
  vim.bo.formatoptions
)
check(
  "gitcommit keeps autowrap flag t",
  vim.bo.formatoptions:find("t") ~= nil,
  vim.bo.formatoptions
)

-- gitrebase shares the same autocmd, so it gets the same treatment.
open_as("gitrebase")
check("gitrebase textwidth is 75", vim.bo.textwidth == 75, vim.bo.textwidth)
check(
  "gitrebase formatoptions drops l",
  not vim.bo.formatoptions:find("l"),
  vim.bo.formatoptions
)

-- TextYankPost highlights through vim.hl: vim.highlight is the deprecated alias
-- (removed in 0.13). Shadow the alias so any remaining use errors.
do
  local saved = vim.highlight
  vim.highlight = setmetatable({}, {
    __index = function(_, key)
      error("vim.highlight." .. key .. " is deprecated; use vim.hl")
    end,
  })
  vim.cmd("enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "yank me" })
  local ok, err = pcall(vim.cmd, "normal! yy")
  check("yank highlight does not use vim.highlight", ok, err)
  vim.highlight = saved
end

-- Insert mode shortens the key timeout so `f` shows up promptly when it is not
-- the start of the `fd` escape chord; leaving insert restores whatever the
-- normal-mode value was, so leader and localleader chords keep their time.
-- Headless feedkeys runs insert mode like :normal, entering and leaving within
-- the call, so both values are observed from autocmds registered after the
-- config's own (autocmds run in definition order).
do
  local seen_enter, seen_leave
  local group = vim.api.nvim_create_augroup("autocmds_spec_insert", { clear = true })
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      seen_enter = vim.o.timeoutlen
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      seen_leave = vim.o.timeoutlen
    end,
  })

  vim.cmd("enew")
  vim.o.timeoutlen = 700
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("ia<Esc>", true, false, true), "x", false)
  check("insert mode shortens timeoutlen", seen_enter == 150, seen_enter)
  check("leaving insert restores the previous timeoutlen", seen_leave == 700, seen_leave)
  check("normal mode ends with the previous timeoutlen", vim.o.timeoutlen == 700, vim.o.timeoutlen)

  vim.o.timeoutlen = 600
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("ib<Esc>", true, false, true), "x", false)
  check("the restored value follows the current normal-mode setting", seen_leave == 600, seen_leave)
end

if #failures > 0 then
  io.write("\n" .. #failures .. " failed\n")
  vim.cmd("cquit 1")
else
  io.write("\nall passed\n")
end
