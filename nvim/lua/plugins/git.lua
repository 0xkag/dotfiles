-- Run git in the directory of the current buffer (falls back to cwd) so the
-- right repo is used even when nvim's cwd is elsewhere.
local function git(args)
  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end
  local cmd = { "git", "-C", dir }
  vim.list_extend(cmd, args)
  local out = vim.fn.systemlist(cmd)
  return out, vim.v.shell_error
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

-- Tracks whether the gutter is showing branch changes vs. the default index base.
local review_active = false

local function toggle_branch_review()
  local gs = require("gitsigns")
  if review_active then
    gs.change_base(nil, true)
    review_active = false
    vim.notify("gitsigns: base reset to index (uncommitted changes)")
  else
    local base, branch = branch_merge_base()
    if not base then
      return
    end
    gs.change_base(base, true)
    review_active = true
    vim.notify("gitsigns: reviewing branch changes vs. merge-base with " .. branch)
  end
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
      local gs = require("gitsigns")
      local ref = cmd.args
      if ref == nil or ref == "" then
        gs.change_base(nil, true)
        review_active = false
        vim.notify("gitsigns: base reset to index (uncommitted changes)")
      else
        gs.change_base(ref, true)
        review_active = true
        vim.notify("gitsigns: base set to " .. ref)
      end
    end, { nargs = "?", desc = "Set gitsigns diff base to a git ref (empty resets)" })
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
      "<leader>gd",
      function()
        require("gitsigns").diffthis()
      end,
      desc = "Diff this",
    },
    {
      "<leader>gm",
      toggle_branch_review,
      desc = "Toggle branch review (merge-base diff)",
    },
  },
}
