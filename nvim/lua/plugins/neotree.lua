local util = require("config.util")

-- Neo-tree draws a row out of several glyph sources, and most default to Nerd
-- Font private-use codepoints: seven of the nine git status symbols, the folder
-- icons, the expander arrows, and -- on every file row -- the devicon that
-- icon.provider pulls from nvim-web-devicons. Those come out as tofu wherever
-- the font is not patched, PuTTY into Linux included. The plain profile below
-- replaces exactly those and keeps the ones that are ordinary Unicode (the
-- indent markers, the added/deleted marks, the symlink arrow), which render
-- fine in an unpatched font -- verified in PuTTY + tmux. Plain is the default,
-- with <leader>tg for the full Nerd Font set.
local plain_config = {
  git_status = {
    -- Replaces the whole symbol table, so the two standard-Unicode marks have
    -- to be repeated here rather than omitted.
    symbols = {
      added = "✚",
      conflict = "!",
      deleted = "✖",
      ignored = "I",
      modified = "M",
      renamed = "R",
      staged = "+",
      unstaged = "*",
      untracked = "?",
    },
  },
  -- A blank file icon rather than a character: the status column already owns
  -- the right-hand side of the row, and anything put here reads as a status
  -- too. "*" was the worst of both, since it is also the unstaged mark, so it
  -- appeared twice on one line meaning two different things. Directories keep
  -- +/- because open-vs-closed is real information; an empty directory gets "-"
  -- because "+" implies something to expand and there is nothing.
  icon = {
    default = " ",
    folder_closed = "+",
    folder_empty = "-",
    folder_empty_open = "-",
    folder_open = "-",
  },
  -- Only the expanders: indent_marker and last_indent_marker default to box
  -- drawing, which needs no patched font, so they are left alone.
  indent = {
    expander_collapsed = ">",
    expander_expanded = "v",
  },
}

-- Keys to drop rather than replace: icon.provider is the hook that reaches for
-- nvim-web-devicons, and every glyph it returns is private use, so the plain
-- profile has to remove it and let icon.default stand in.
local plain_drop = {
  icon = { "provider" },
}

local sources = { "buffers", "filesystem", "git_status" }
local profile = "plain"

-- Wrapping the components is what makes the profile switchable at runtime.
-- Neo-tree copies component config into per-state renderers when a tree is
-- built and its setup() mutates persistent module tables instead of rebuilding
-- them, so neither re-running setup nor rewriting the resolved config swaps the
-- glyphs in a live session. Re-running setup is the trap worth naming: the
-- first swap appears to work and every one after it sticks on the old glyphs,
-- because the module tables it mutates have already been rewritten. A component
-- function, though, is looked up per render (ui/renderer.lua
-- state.components[name]), so reading the profile here means a redraw is all a
-- toggle needs. `original` is whatever that source actually uses, since a
-- source's components module is a merge of the common ones with its own.
local function plain_wrapper(name, original)
  return function(config, node, state)
    if profile == "plain" then
      config = vim.tbl_extend("force", config, plain_config[name])
      for _, key in ipairs(plain_drop[name] or {}) do
        config[key] = nil
      end
    end
    return original(config, node, state)
  end
end

-- Files this branch committed since the diff base. Neo-tree's own status covers
-- the worktree, so it never marks a file that was changed three commits ago and
-- is clean now; these fill that in, which is what lines the tree up with
-- <leader>gc and the file pickers. Upstream can do this via
-- `:Neotree git_base=<ref>`, but that path throws on every row at the tip of
-- v3.x, and it renders base-derived changes with the same highlight as
-- uncommitted ones -- it computes a status_from_diff flag and ignores it.
local base_marks = {}
local base_marks_key = nil
local base_marks_stale = true

-- One git call per refresh, not per row: the first node of a redraw recomputes
-- and the rest read the cache. The key folds in the base generation, so a
-- <leader>gm press invalidates it without a subscription; the stale flag covers
-- a tree refresh, where the paths may have changed but the base has not.
local function base_marks_for(state)
  local gitdiff = require("config.gitdiff")
  local root = state and state.path
  local key = (root or "") .. "\0" .. gitdiff.generation()
  if not base_marks_stale and base_marks_key == key then
    return base_marks
  end

  base_marks, base_marks_key, base_marks_stale = {}, key, false
  local top = root and gitdiff.repo_toplevel(root, true)
  if not top then
    return base_marks
  end

  for _, file in ipairs(gitdiff.committed_files(top)) do
    local path = vim.fs.joinpath(top, file.path)
    base_marks[path] = gitdiff.status_mark(file.status)

    -- Bubble up, so a collapsed directory still shows that something under it
    -- changed since the base, the way neo-tree bubbles its own statuses.
    local parent = vim.fs.dirname(path)
    while parent and #parent > #top do
      base_marks[parent] = base_marks[parent] or "M"
      parent = vim.fs.dirname(parent)
    end
  end
  return base_marks
end

-- git's change letters onto the symbol names the status component knows.
local mark_symbols = {
  A = "added",
  C = "added",
  D = "deleted",
  M = "modified",
  R = "renamed",
}

-- Did the wrapped component actually mark this node? It returns an empty table
-- when git status has nothing to say, which is the opening for the base marks.
local function marked(rendered)
  if not rendered then
    return false
  end
  if rendered[1] then
    return true
  end
  return rendered.text ~= nil and vim.trim(rendered.text) ~= ""
end

-- Worktree status wins where both apply, since not-yet-committed is the more
-- urgent fact; the base marks use their own highlight rather than a second
-- column, so "already committed" reads differently at the same width.
local function git_status_wrapper(original)
  return function(config, node, state)
    if profile == "plain" then
      config = vim.tbl_extend("force", config, plain_config.git_status)
    end

    local rendered = original(config, node, state)
    if marked(rendered) then
      return rendered
    end

    local mark = node and node.path and base_marks_for(state)[node.path]
    if not mark then
      return rendered
    end

    local symbols = config.symbols or {}
    return {
      highlight = "NeoTreeGitBase",
      text = (symbols[mark_symbols[mark] or "modified"] or mark) .. " ",
    }
  end
end

-- ]g and [g walk neo-tree's own status table (filesystem/commands.lua:157)
-- rather than what the row actually rendered, so the base marks are invisible to
-- them, and they skip untracked files outright. Jump over the same set the tree
-- marks instead: neo-tree's worktree status minus ignored, plus the base-only
-- paths, with untracked included because every other view here counts those as
-- changed. The walk mirrors neo-tree's own -- sort by tree display, take the
-- first file as a fallback, and the first file past the cursor wins.
local function jump_changed(reverse)
  return function(state)
    local nt_utils = require("neo-tree.utils")
    local uv = vim.uv or vim.loop

    local node = state.tree and state.tree:get_node()
    local current = node and node:get_id()

    local seen, paths = {}, {}
    local function add(path)
      if not seen[path] and state.path and nt_utils.is_subpath(state.path, path) then
        seen[path] = true
        table.insert(paths, path)
      end
    end

    if current then
      add(current)
    end
    -- One source for the candidates rather than neo-tree's worktree cache: at
    -- the index base this is git status, against a ref it is the diff plus the
    -- untracked files, so it already covers committed and uncommitted changes
    -- alike and matches exactly what the rows are marked with. It also avoids a
    -- quirk that bit the first version -- find_existing_worktree deliberately
    -- returns nothing when handed the worktree root itself, which is what
    -- state.path usually is.
    for path in pairs(require("config.gitdiff").status_by_path(state.path, true)) do
      add(path)
    end

    local function is_file(path)
      local ok, stat = pcall(uv.fs_stat, path)
      return (ok and stat and stat.type ~= "directory") or false
    end

    local sorted = nt_utils.sort_by_tree_display(paths)
    local from, to, step = 1, #sorted, 1
    if reverse then
      from, to, step = #sorted, 1, -1
    end

    local target, passed = nil, false
    for i = from, to, step do
      local path = sorted[i]
      if target == nil and is_file(path) then
        target = path
      end
      if passed then
        if is_file(path) then
          target = path
          break
        end
      elseif path == current then
        passed = true
      end
    end

    if not target then
      vim.notify("neo-tree: nothing changed vs " .. require("config.gitdiff").label())
      return
    end
    if state.tree:get_node(target) then
      require("neo-tree.ui.renderer").focus_node(state, target)
    else
      require("neo-tree.sources.filesystem").navigate(state, state.path, target, nil, false)
    end
  end
end

-- The window and displayed root of an open filesystem tree in this tab, or nil.
local function tree_path()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
      local ok, state = pcall(require("neo-tree.sources.manager").get_state, "filesystem")
      return ok and state and state.path or nil
    end
  end
  return nil
end

-- Glyphs are resolved as the tree is drawn, so an open tree has to be rebuilt
-- to show the other profile; closing and revealing the same root is the cheapest
-- way to force that.
local function profile_toggle()
  profile = profile == "plain" and "nerd" or "plain"

  local path = tree_path()
  if path then
    vim.cmd("Neotree close")
    vim.cmd("Neotree reveal dir=" .. vim.fn.fnameescape(path))
  end
  vim.notify("neo-tree glyphs: " .. profile)
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  cmd = "Neotree",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  config = function(_, opts)
    -- Register before setup: it reads each source's components module to decide
    -- which components its renderers may use.
    for _, source in ipairs(sources) do
      local components = require("neo-tree.sources." .. source .. ".components")
      for name in pairs(plain_config) do
        if name == "git_status" then
          components[name] = git_status_wrapper(components[name])
        else
          components[name] = plain_wrapper(name, components[name])
        end
      end
    end

    -- Linked rather than coloured outright so a theme can claim it, and re-set
    -- on ColorScheme because a colorscheme load clears it.
    local function base_highlight()
      vim.api.nvim_set_hl(0, "NeoTreeGitBase", { default = true, link = "Comment" })
    end
    base_highlight()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = base_highlight,
      desc = "Keep the neo-tree diff-base highlight after a colorscheme load",
    })

    -- The two recompute triggers: a tree refresh, which is exactly when
    -- neo-tree recomputes its own git status, and a change of diff base.
    local events = require("neo-tree.events")
    events.subscribe({
      event = events.GIT_STATUS_CHANGED,
      handler = function()
        base_marks_stale = true
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      pattern = "GitDiffBaseChanged",
      callback = function()
        base_marks_stale = true
        if tree_path() then
          require("neo-tree.sources.manager").refresh("filesystem")
        end
      end,
      desc = "Redraw the neo-tree diff-base marks when the base changes",
    })

    require("neo-tree").setup(opts)
  end,
  keys = {
    { "<leader>oe", "<cmd>Neotree toggle<cr>", desc = "Explorer toggle" },
    { "<leader>oE", "<cmd>Neotree reveal<cr>", desc = "Reveal current file" },
    { "<leader>ft", "<cmd>Neotree toggle<cr>", desc = "File tree toggle" },
    { "<leader>fT", "<cmd>Neotree reveal<cr>", desc = "Reveal current file" },
    {
      "<leader>pe",
      function()
        vim.cmd("Neotree reveal dir=" .. vim.fn.fnameescape(util.project_root(0)))
      end,
      desc = "Project explorer",
    },
    {
      "<leader>pt",
      function()
        vim.cmd("Neotree reveal dir=" .. vim.fn.fnameescape(util.project_root(0)))
      end,
      desc = "Project tree",
    },
    {
      "<leader>tg",
      profile_toggle,
      desc = "Toggle neo-tree glyphs (plain/Nerd Font)",
    },
  },
  opts = {
    close_if_last_window = false,
    filesystem = {
      follow_current_file = {
        enabled = true,
      },
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      hijack_netrw_behavior = "open_current",
      use_libuv_file_watcher = true,
    },
    window = {
      -- neo-tree maps <space> to toggle_node without nowait, which leaves the
      -- leader key ambiguous inside the tree: nvim waits timeoutlen (500ms)
      -- after <space> and, if the rest of the sequence is not typed in time,
      -- runs toggle_node and swallows the leader press. which-key's hint only
      -- appears at 300ms, so pausing to read it loses the race. <cr> already
      -- expands and collapses directories, so drop the <space> binding.
      mappings = {
        ["<space>"] = "none",
        ["[g"] = { jump_changed(true), desc = "Prev changed file (vs diff base)" },
        ["]g"] = { jump_changed(false), desc = "Next changed file (vs diff base)" },
      },
      width = 32,
    },
  },
}
