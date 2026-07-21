-- Run git in `dir` so the right repo is used regardless of nvim's cwd.
local function git_in(dir, args)
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  local out = vim.fn.systemlist(cmd)
  return out, vim.v.shell_error
end

-- Run git in the directory of the current buffer (falls back to cwd).
local function git(args)
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end
  return git_in(dir, args)
end

-- Best guess at the repo's default branch: prefer origin/HEAD, then main/master.
local function default_branch()
  local out, code = git({ "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" })
  if code == 0 and out[1] and out[1] ~= "" then
    return (out[1]:gsub("^origin/", ""))
  end
  for _, b in ipairs({ "main", "master" }) do
    local _, c = git({ "rev-parse", "--verify", "--quiet", b })
    if c == 0 then
      return b
    end
  end
  return nil
end

-- Commit where the current branch forked off the default branch. Diffing
-- against this shows only the lines THIS branch changed, ignoring commits the
-- base branch made after the fork point.
local function branch_merge_base()
  local branch = default_branch()
  if not branch then
    vim.notify("gitsigns: could not find a main/master branch", vim.log.levels.WARN)
    return nil
  end
  local out, code = git({ "merge-base", branch, "HEAD" })
  if code ~= 0 or not out[1] or out[1] == "" then
    vim.notify("gitsigns: could not compute merge-base with " .. branch, vim.log.levels.WARN)
    return nil
  end
  return out[1], branch
end

-- Open read-only text in a scratch buffer in a new tab. `legend` is shown in
-- the winbar so the buffer's keymaps (q, and any added by the caller) are
-- discoverable. Returns the buffer so callers can add their own maps.
local function scratch(lines, ft, legend)
  vim.cmd.tabnew()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local bo = vim.bo[buf]
  bo.buftype = "nofile"
  bo.bufhidden = "wipe"
  bo.filetype = ft
  bo.modifiable = false
  vim.wo.winbar = legend
  vim.keymap.set("n", "q", "<cmd>tabclose<cr>", { buffer = buf, desc = "Close" })
  return buf
end

-- Open `src_bufnr` (a gitsigns-attached real-file buffer) at `sha` in a new tab
-- as a read-only revision buffer, via the same show path reblame() uses. When
-- `with_blame`, also open the blame panel so r/R cycling continues from that
-- revision; otherwise it is just the full file at that commit.
local function open_revision(src_bufnr, sha, with_blame)
  local gs = require("gitsigns")
  vim.cmd("tab sbuffer " .. src_bufnr)
  gs.show(sha, function(err)
    if err then
      vim.notify("gitsigns at " .. sha .. ": " .. err, vim.log.levels.ERROR)
      return
    end
    if with_blame then
      gs.blame()
    end
  end)
end

-- The real-file source window scroll-bound to the current blame buffer, or nil
-- (e.g. after reblame, where the source is a gitsigns:// revision buffer).
-- Returns win, buf, filepath.
local function blame_source_window()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    local name = vim.api.nvim_buf_get_name(b)
    if vim.bo[b].filetype ~= "gitsigns-blame" and vim.fn.filereadable(name) == 1 then
      return w, b, name
    end
  end
  return nil
end

-- Full sha of the commit that last touched line `lnum` of `file` (the first
-- token of git blame --porcelain). The blame buffer is line-bound 1:1 with the
-- source, so the cursor line maps straight through.
local function sha_for_line(file, lnum)
  local out, code = git_in(vim.fn.fnamemodify(file, ":h"),
    { "blame", "-L", lnum .. "," .. lnum, "--porcelain", "--", file })
  if code ~= 0 or not out[1] then
    return nil
  end
  return out[1]:match("^(%x+)")
end

-- The SHA of the commit whose git-log section the cursor sits in: scan upward
-- for the nearest "commit <sha>" header.
local function commit_sha_at_cursor()
  for i = vim.fn.line("."), 1, -1 do
    local sha = vim.fn.getline(i):match("^commit (%x+)")
    if sha then
      return sha
    end
  end
  return nil
end

-- Resolve the (buffer, file, line1, line2) to run git log -L against from the
-- current window. In a normal file that is the buffer and cursor/visual range.
-- In gitsigns' blame buffer it is the scroll-bound source window in the tab
-- (its lines are aligned with the blame buffer, so the cursor line maps 1:1).
local function log_target()
  local line1 = vim.fn.line(".")
  local line2 = line1
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    line1 = vim.fn.line("v")
    line2 = vim.fn.line(".")
    if line1 > line2 then
      line1, line2 = line2, line1
    end
    vim.cmd("normal! \27")
  end

  if vim.bo.filetype == "gitsigns-blame" then
    local _, b, name = blame_source_window()
    if b then
      return b, name, line1, line2
    end
    vim.notify("git log -L: no source file window (reblamed revisions are not supported)", vim.log.levels.WARN)
    return nil
  end

  local file = vim.fn.expand("%:p")
  if file == "" or vim.fn.filereadable(file) == 0 then
    vim.notify("git log -L: current buffer has no file on disk", vim.log.levels.WARN)
    return nil
  end
  return vim.api.nvim_get_current_buf(), file, line1, line2
end

-- Follow a line (or a visual selection) backwards through history with
-- git log -L, unlike blame's R this tracks where the line MOVED across
-- revisions instead of reusing the same line number in a shifted file.
local function log_line_history()
  local src_bufnr, file, line1, line2 = log_target()
  if not src_bufnr then
    return
  end

  local spec = string.format("%d,%d:%s", line1, line2, file)
  local out, code = git_in(vim.fn.fnamemodify(file, ":h"), { "log", "-L", spec, "--no-color" })
  if code ~= 0 then
    vim.notify("git log -L failed: " .. table.concat(out, "\n"), vim.log.levels.ERROR)
    return
  end

  local legend = string.format("  git log -L %d,%d  (%s)    b blame   o open file   q quit", line1, line2, vim.fn.fnamemodify(file, ":t"))
  local buf = scratch(out, "git", legend)

  -- gitsigns.show() reads the attached source buffer's cache, so both maps act
  -- on the commit under the cursor via src_bufnr.
  local function with_sha(fn)
    return function()
      local sha = commit_sha_at_cursor()
      if not sha then
        vim.notify("git log -L: no commit under the cursor", vim.log.levels.WARN)
        return
      end
      fn(sha)
    end
  end

  vim.keymap.set("n", "b", with_sha(function(sha)
    open_revision(src_bufnr, sha, true)
  end), { buffer = buf, desc = "Blame file at the commit under the cursor" })

  vim.keymap.set("n", "o", with_sha(function(sha)
    open_revision(src_bufnr, sha, false)
  end), { buffer = buf, desc = "Open the full file at the commit under the cursor" })
end

-- True when HEAD is the default branch (commits go straight onto it).
local function on_default_branch()
  local out, code = git({ "rev-parse", "--abbrev-ref", "HEAD" })
  return code == 0 and out[1] == default_branch()
end

-- The remote-tracking ref of the default branch (e.g. origin/master), or nil
-- when it does not exist (no remote).
local function origin_default()
  local branch = default_branch()
  if not branch then
    vim.notify("gitsigns: could not find a main/master branch", vim.log.levels.WARN)
    return nil
  end
  local ref = "origin/" .. branch
  local _, code = git({ "rev-parse", "--verify", "--quiet", ref })
  if code ~= 0 then
    vim.notify("gitsigns: no " .. ref .. " ref (no remote?)", vim.log.levels.WARN)
    return nil
  end
  return ref
end

-- <leader>gm cycles the gitsigns diff base:
--   index -> merge-base -> origin/<default> -> index
-- The very first press instead jumps to the most useful base for the context:
-- origin/<default> when HEAD is the default branch (unpushed commits),
-- merge-base otherwise (branch changes). After a manual base (<leader>gM or
-- :GitsignsBase) the next press restarts the cycle at index.
local base_ref = nil -- ref currently applied, nil at the index base
local base_smart = true -- true until the first <leader>gm press
local base_state = "index" -- index | merge-base | origin | manual

-- Pure cycle step: the state a <leader>gm press moves to from `state`.
local function base_next(state, smart, on_default)
  if state == "index" then
    if smart then
      return on_default and "origin" or "merge-base"
    end
    return "merge-base"
  elseif state == "merge-base" then
    return "origin"
  end
  return "index"
end

-- Move to `state`, resolving and applying its base ref. If the ref cannot be
-- resolved, warn and stay on the current base.
local function base_apply(state)
  local gs = require("gitsigns")
  if state == "index" then
    gs.change_base(nil, true)
    base_state, base_ref = "index", nil
    vim.notify("gitsigns: base reset to index (uncommitted changes)")
  elseif state == "merge-base" then
    local base, branch = branch_merge_base()
    if not base then
      return
    end
    gs.change_base(base, true)
    base_state, base_ref = "merge-base", base
    vim.notify("gitsigns: diff vs merge-base with " .. branch .. " (branch changes)")
  else
    local ref = origin_default()
    if not ref then
      return
    end
    gs.change_base(ref, true)
    base_state, base_ref = "origin", ref
    vim.notify("gitsigns: diff vs " .. ref .. " (unpushed + uncommitted)")
  end
end

local function base_cycle()
  local state = base_next(base_state, base_smart, on_default_branch())
  base_smart = false
  base_apply(state)
end

-- Apply an explicit base ref; nil/empty resets to index. Shared by
-- :GitsignsBase and <leader>gM.
local function base_set(ref)
  if ref == nil or ref == "" then
    base_apply("index")
    return
  end
  require("gitsigns").change_base(ref, true)
  base_state, base_ref = "manual", ref
  vim.notify("gitsigns: base set to " .. ref)
end

-- Prompt for a base ref, prefilled with the active base or, at index, the
-- ref the smart first press would pick. Empty input resets to index.
local function base_prompt()
  local prefill = base_ref
  if not prefill then
    if on_default_branch() then
      prefill = origin_default()
    else
      prefill = branch_merge_base()
    end
  end
  vim.ui.input({ prompt = "gitsigns base (empty = index): ", default = prefill or "" }, function(input)
    if input then
      base_set(input)
    end
  end)
end

return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    current_line_blame = false,
    numhl = true,
    signcolumn = true,
  },
  config = function(_, opts)
    require("gitsigns").setup(opts)

    -- :GitsignsBase <ref>  -> diff gutter against any ref (all buffers).
    -- :GitsignsBase        -> reset to the default index base.
    vim.api.nvim_create_user_command("GitsignsBase", function(cmd)
      base_set(cmd.args)
    end, { nargs = "?", desc = "Set gitsigns diff base to a git ref (empty resets)" })

    -- Fix up gitsigns' blame buffer. gitsigns maps r/R/d/s/S/<CR> without
    -- nowait, so they stall behind global multi-key maps (nvim-surround's ds,
    -- flash's s/S); re-register them with nowait so they fire immediately. It
    -- also maps no q, and sizes the window to its content (too narrow for the
    -- legend), so add q and grow the window to fit the legend in the winbar.
    local legend = "r/R reblame  d diff  s/S show  o open file  <CR> menu  q quit"
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "gitsigns-blame",
      desc = "Fix keys, add q/o, and show a legend in the gitsigns blame buffer",
      callback = function(ev)
        vim.wo.winbar = "  " .. legend
        vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, desc = "Close blame" })

        -- o: open the full file at the commit that touched the line under the
        -- cursor. The blame buffer is line-bound 1:1 with its scroll-bound
        -- source window, so the cursor line maps straight through.
        vim.keymap.set("n", "o", function()
          local _, src_buf, file = blame_source_window()
          if not src_buf then
            vim.notify("blame: no source file window (already at a revision)", vim.log.levels.WARN)
            return
          end
          local lnum = vim.api.nvim_win_get_cursor(0)[1]
          local sha = sha_for_line(file, lnum)
          if not sha then
            vim.notify("blame: could not resolve the commit for this line", vim.log.levels.WARN)
            return
          end
          open_revision(src_buf, sha, false)
        end, { buffer = ev.buf, nowait = true, desc = "Open full file at this line's commit" })

        local need = vim.fn.strdisplaywidth(legend) + 3
        if vim.api.nvim_win_get_width(0) < need then
          pcall(vim.api.nvim_win_set_width, 0, need)
        end

        -- gitsigns sets its maps after this FileType fires, so defer the nowait
        -- pass until they exist. Only single-char keys (d/s/S/r/R/q) collide
        -- with the surround/flash prefixes; re-set those preserving their
        -- callback/expr, and leave multi-key maps like <CR> alone.
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(ev.buf) then
            return
          end
          for _, m in ipairs(vim.api.nvim_buf_get_keymap(ev.buf, "n")) do
            if #m.lhs == 1 then
              vim.keymap.set("n", m.lhs, m.callback or m.rhs, {
                buffer = ev.buf,
                nowait = true,
                expr = m.expr == 1,
                silent = m.silent == 1,
                desc = m.desc,
              })
            end
          end
        end)
      end,
    })
  end,
  keys = {
    {
      "]h",
      function()
        require("gitsigns").next_hunk()
      end,
      desc = "Next hunk",
    },
    {
      "[h",
      function()
        require("gitsigns").prev_hunk()
      end,
      desc = "Previous hunk",
    },
    {
      "<leader>gs",
      function()
        require("gitsigns").stage_hunk()
      end,
      desc = "Stage hunk",
    },
    {
      "<leader>gr",
      function()
        require("gitsigns").reset_hunk()
      end,
      desc = "Reset hunk",
    },
    {
      "<leader>gp",
      function()
        require("gitsigns").preview_hunk()
      end,
      desc = "Preview hunk",
    },
    {
      "<leader>gb",
      function()
        require("gitsigns").blame_line({ full = true })
      end,
      desc = "Blame line",
    },
    {
      "<leader>gB",
      function()
        require("gitsigns").toggle_current_line_blame()
      end,
      desc = "Toggle line blame",
    },
    {
      -- Full-file blame buffer. In it: r = reblame at commit, R = reblame at
      -- parent (the <hash>^ before this change), <CR> = menu, s/S = show commit.
      "<leader>gl",
      function()
        require("gitsigns").blame()
      end,
      desc = "Blame file (reblame with r/R)",
    },
    {
      -- git log -L: -L mnemonic, follows the line across revisions. In the
      -- buffer, b opens gitsigns' interactive blame at the commit under cursor.
      "<leader>gL",
      log_line_history,
      mode = { "n", "x" },
      desc = "Log line history (git log -L, follows the line)",
    },
    {
      "<leader>gd",
      function()
        require("gitsigns").diffthis()
      end,
      desc = "Diff this",
    },
    {
      "<leader>gm",
      base_cycle,
      desc = "Cycle diff base (index / merge-base / origin)",
    },
    {
      "<leader>gM",
      base_prompt,
      desc = "Set diff base to a ref (prompt)",
    },
  },
}
