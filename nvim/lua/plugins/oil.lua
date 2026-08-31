local util = require("config.util")

-- Oil renders one column cell per line, so the marks are cached per directory
-- and diff-base generation the same way the tree's are: one git call per redraw
-- rather than one per file.
local marks = {}
local marks_key = nil

local function marks_for(bufnr)
  local gitdiff = require("config.gitdiff")
  local dir = require("oil").get_current_dir(bufnr)
  local key = (dir or "") .. "\0" .. gitdiff.generation()
  if marks_key == key then
    return marks
  end

  -- Quiet: a directory editor can be pointed anywhere, and being outside a repo
  -- is normal rather than something to complain about on every redraw.
  marks, marks_key = dir and gitdiff.status_by_path(dir, true) or {}, key
  return marks
end

-- A git status column, so the directory editor marks what changed against the
-- active diff base the way the file pickers and the tree do. Oil substitutes a
-- dimmed "-" of its own whenever a cell renders blank, which is what unchanged
-- files get.
--
-- Unlike the tree, a base change does not redraw this on its own: an oil buffer
-- can be holding unsaved filesystem edits, and refreshing discards them (it
-- prompts, and with force does not even do that), so triggering a refresh to
-- update a cosmetic column risks destroying a bulk rename in progress. The
-- marks are right on any redraw the user asks for -- <C-l> is oil's refresh --
-- because the cache key carries the base generation.
local function register_git_column()
  local constants = require("oil.constants")
  local gitdiff = require("config.gitdiff")

  require("oil.columns").register("git_status", {
    render = function(entry, _, bufnr)
      local name = entry[constants.FIELD_NAME]
      local dir = require("oil").get_current_dir(bufnr)
      if not name or not dir then
        return ""
      end

      local mark = marks_for(bufnr)[vim.fs.joinpath(dir, name)]
      if not mark or mark == "" then
        return ""
      end
      return { mark, gitdiff.status_highlight(mark) }
    end,

    -- Required: oil parses every column back off the line when it applies an
    -- edit. One token then the rest, the same shape the icon column uses; a
    -- blank cell never reaches here, since oil strips its own "-" first.
    parse = function(line)
      return line:match("^(%S+)%s+(.*)$")
    end,
  })
end

return {
  "stevearc/oil.nvim",
  lazy = false,
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "Oil" },
  config = function(_, opts)
    register_git_column()
    require("oil").setup(opts)
  end,
  keys = {
    { "<leader>od", "<cmd>Oil<cr>", desc = "Directory editor" },
    {
      "<leader>oD",
      function()
        require("oil").open(util.project_root(0))
      end,
      desc = "Project directory editor",
    },
  },
  opts = {
    default_file_explorer = true,
    columns = { "git_status", "icon" },
    delete_to_trash = false,
    skip_confirm_for_simple_edits = false,
    view_options = {
      show_hidden = true,
      natural_order = "fast",
    },
    keymaps = {
      ["q"] = { "actions.close", mode = "n" },
      ["<Esc>"] = { "actions.close", mode = "n" },
      ["<C-g>"] = { "actions.close", mode = "n" },
    },
  },
}
