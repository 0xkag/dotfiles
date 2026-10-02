local util = require("config.util")

-- vifm, the two-pane file manager, in a terminal buffer: files picked there
-- open here. Its preview pane (w) shows images as colored text through
-- ~/.dotfiles/vifm/vifmrc and image-view, which nothing native here can do in
-- a terminal without the kitty graphics protocol. The plugin comes from its own
-- repository rather than the copy vifm installs, whose location depends on how
-- vifm was installed.
return {
  "vifm/vifm.vim",
  cmd = { "DiffVifm", "EditVifm", "PeditVifm", "SplitVifm", "TabVifm", "Vifm", "VsplitVifm" },
  -- Plain mappings rather than lazy's `keys`, whose stubs are expr mappings
  -- that load the plugin under textlock, where the bare `drop` vifm.vim runs
  -- to probe for :drop fails with E565. Running :Vifm lets lazy's command stub
  -- load it instead.
  init = function()
    vim.keymap.set("n", "<leader>ov", "<cmd>Vifm<cr>", { desc = "File manager (vifm)" })
    -- vim.cmd passes the path as one argument, spaces and all, so escaping it
    -- would leave the backslashes in.
    vim.keymap.set("n", "<leader>oV", function()
      vim.cmd.Vifm(util.project_root(0))
    end, { desc = "Project file manager (vifm)" })
  end,
}
