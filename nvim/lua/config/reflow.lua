-- Reflow (structure-preserving) vs restyle (authoritative formatter) logic.
-- See nvim/FORMATTING_NOTES.md for background.
local M = {}

-- Session-wide mode driving what `gq` does. `gQ`/,=q always restyle.
M.mode = "builtin"

local MODES = { "builtin", "lsp", "smart", "conservative" }

function M.cycle()
  local idx = 1
  for i, name in ipairs(MODES) do
    if name == M.mode then
      idx = i
      break
    end
  end
  M.mode = MODES[(idx % #MODES) + 1]
  vim.notify("reflow mode: " .. M.mode, vim.log.levels.INFO)
  return M.mode
end

-- Live visual selection as {start={line,col}, end={line,col}} bounds, with
-- rows 1-indexed and columns 0-indexed (matching conform's range and the
-- mark-based opfunc producer).
-- Reads getpos("v")/getpos(".") because '< '> are only updated after leaving
-- visual mode; <Cmd> mappings fire while still IN visual mode.
function M.selection_range()
  local v = vim.fn.getpos("v")
  local c = vim.fn.getpos(".")
  local s_line, s_col, e_line, e_col = v[2], v[3], c[2], c[3]
  if (s_line > e_line) or (s_line == e_line and s_col > e_col) then
    s_line, e_line = e_line, s_line
    s_col, e_col = e_col, s_col
  end
  return { start = { s_line, s_col - 1 }, ["end"] = { e_line, e_col - 1 } }
end

-- Original visual selection (mode + 1-indexed start/end positions, as setpos
-- 4-lists) of the last visual reflow/restyle, stashed so `,=v` can restore the
-- exact pre-op selection -- reflow_builtin's internal `[V`]gq clobbers '< '>,
-- so gv alone cannot recover the original columns or charwise/blockwise mode.
M._last_visual = nil

-- Capture the live visual selection for later exact restore. Call from a visual
-- map while still IN visual mode (getpos("v")/getpos(".") are live then).
function M.stash_visual()
  M._last_visual = {
    mode = vim.fn.mode(),
    start = vim.fn.getpos("v"),
    ["end"] = vim.fn.getpos("."),
  }
end

-- Reselect the exact selection stashed by stash_visual (mode + columns). No-op
-- if nothing has been stashed this session.
function M.reselect_visual()
  local s = M._last_visual
  if not s then
    return
  end
  vim.fn.setpos(".", s.start)
  vim.cmd("normal! " .. s.mode)
  vim.fn.setpos(".", s["end"])
end

-- Structure-preserving reflow via Vim's built-in formatter.
-- Blank indentexpr/formatexpr so gq does not get rerouted to the LSP range
-- formatter (re-indent only, no reflow) or treesitter indentexpr (drops
-- comment-continuation lines to column 0). With a range, reflow exactly those
-- lines; without one, fall back to the '[ '] operator marks.
function M.reflow_builtin(range)
  local indentexpr, formatexpr = vim.bo.indentexpr, vim.bo.formatexpr
  vim.bo.indentexpr, vim.bo.formatexpr = "", ""
  if range then
    -- The visual gq/gQ maps call this while still IN visual mode; leave it
    -- first so the V below starts a fresh selection instead of toggling off.
    if vim.api.nvim_get_mode().mode:match("[vV\22]") then
      vim.cmd("normal! \27")
    end
    vim.cmd(string.format("normal! %dGV%dGgq", range.start[1], range["end"][1]))
  else
    vim.cmd("normal! `[V`]gq")
  end
  vim.bo.indentexpr, vim.bo.formatexpr = indentexpr, formatexpr
  -- Signal a synchronous reflow: '[ '] now span the reflowed extent, so the
  -- visual maps can reselect the real (possibly grown) region.
  return true
end

-- Authoritative restyle via conform (LSP fallback). In conservative mode,
-- target autopep8 for python (fix-violations-only); if autopep8 is unavailable
-- fall back to built-in reflow with a one-time notify.
local warned_no_autopep8 = false

function M.restyle(range)
  local conform = require("conform")
  local opts = { async = true, bufnr = 0, lsp_format = "fallback", range = range }

  if M.mode == "conservative" and vim.bo.filetype == "python" then
    if conform.get_formatter_info("autopep8", 0).available then
      opts.formatters = { "autopep8" }
    else
      if not warned_no_autopep8 then
        vim.notify("autopep8 not available; using built-in reflow", vim.log.levels.WARN)
        warned_no_autopep8 = true
      end
      return M.reflow_builtin(range)
    end
  end

  conform.format(opts)
end

-- True if the treesitter node at (line,col) (0-indexed) is a comment/string.
-- Forces a parse first: get_node returns nil on an unparsed tree (e.g. a freshly
-- loaded buffer), which would otherwise make smart mode misclassify everything.
local function is_prose_node(line, col)
  local ok = pcall(function()
    vim.treesitter.get_parser(0):parse(true)
  end)
  if not ok then
    return false
  end
  local node
  ok, node = pcall(vim.treesitter.get_node, { pos = { line, col } })
  if not ok or not node then
    return false
  end
  local t = node:type()
  return t:find("comment") ~= nil or t:find("string") ~= nil
end

-- Single entry for all reflow/restyle mappings.
-- range: {start={line,col}, end={line,col}} row 1-indexed, col 0-indexed, or
-- nil to use '[ '] marks.
-- force_restyle: gQ/,=q pass true to always restyle regardless of mode.
function M.dispatch_range(range, force_restyle)
  if force_restyle then
    return M.restyle(range)
  end
  if M.mode == "builtin" then
    return M.reflow_builtin(range)
  elseif M.mode == "lsp" or M.mode == "conservative" then
    return M.restyle(range)
  elseif M.mode == "smart" then
    local start = range and range.start or vim.api.nvim_buf_get_mark(0, "[")
    local line = (range and range.start[1] or start[1]) - 1
    local col = range and range.start[2] or 0
    if is_prose_node(line, col) then
      return M.reflow_builtin(range)
    end
    return M.restyle(range)
  end
  return M.reflow_builtin()
end

-- Operator-func target for normal-mode gq{motion}/gQ{motion}. Set
-- M._pending_restyle before triggering g@ to choose reflow vs restyle.
function M.opfunc()
  local range = {
    start = vim.api.nvim_buf_get_mark(0, "["),
    ["end"] = vim.api.nvim_buf_get_mark(0, "]"),
  }
  M.dispatch_range(range, M._pending_restyle == true)
end

return M
