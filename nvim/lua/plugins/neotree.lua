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
        components[name] = plain_wrapper(name, components[name])
      end
    end

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
      },
      width = 32,
    },
  },
}
