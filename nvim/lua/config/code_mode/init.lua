-- Spacemacs-style language "code mode": per-filetype localleader keymaps for
-- tests, debugging, imports, scaffolding, and git editors.
--
-- The language helpers live in submodules (go/java/markdown/shell/python_debug/
-- terraform/git_editor) and are merged onto this module's M so the public API
-- (require("config.code_mode").<action>) is unchanged. setup() registers the
-- FileType autocmds that bind those actions per buffer.
local M = {}

local submodules = {
  require("config.code_mode.go"),
  require("config.code_mode.java"),
  require("config.code_mode.markdown"),
  require("config.code_mode.shell"),
  require("config.code_mode.python_debug"),
  require("config.code_mode.terraform"),
  require("config.code_mode.git_editor"),
}

for _, mod in ipairs(submodules) do
  for name, fn in pairs(mod) do
    if name:sub(1, 1) ~= "_" then -- skip test-only (_-prefixed) helpers
      M[name] = fn
    end
  end
end

local shared = require("config.code_mode.shared")

function M.setup()
  local group = vim.api.nvim_create_augroup("user_code_mode_actions", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "python",
    callback = function(event)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("n", "<leader>dd", M.python_debug_file, "Debug file")
      map("n", "<leader>dt", M.python_debug_nearest_test, "Debug nearest test")
      map("n", "<leader>dT", M.python_debug_file_tests, "Debug file tests")
      map("n", "<leader>dl", M.python_debug_last, "Repeat debug command")
      map("n", "<localleader>dd", M.python_debug_file, "Debug file")
      map("n", "<localleader>dt", M.python_debug_nearest_test, "Debug nearest test")
      map("n", "<localleader>dT", M.python_debug_file_tests, "Debug file tests")
      map("n", "<localleader>dl", M.python_debug_last, "Repeat debug command")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "go",
    callback = function(event)
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("<localleader>ga", M.go_switch_test_file, "Alternate test/source")
      map("<localleader>gc", M.go_coverage_package, "Coverage summary")
      map("<localleader>ig", M.go_goto_imports, "Go to imports")
      map("<localleader>ir", M.go_organize_imports, "Remove unused imports")
      map("<localleader>tp", M.go_test_package, "Run package tests")
      map("<localleader>tP", M.go_test_all, "Run all package tests")
      map("<localleader>tt", M.go_test_nearest, "Run nearest test")
      map("<localleader>tl", M.go_test_last, "Run last test command")
      map("<localleader>xx", M.go_run_package, "Run package")
      map("<localleader>xg", M.go_generate_file, "Generate for file")
      map("<localleader>xG", M.go_generate_project, "Generate for project")
      map("<localleader>ri", M.go_organize_imports, "Organize imports")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "java",
    callback = function(event)
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("<localleader>ga", M.java_switch_test_file, "Alternate test/source")
      map("<localleader>cc", M.java_build_project, "Build project")
      map("<localleader>ta", M.java_run_all_tests, "Run all tests")
      map("<localleader>tc", M.java_run_class_tests, "Run class tests")
      map("<localleader>tt", M.java_run_nearest_test, "Run nearest test")
      map("<localleader>tl", M.java_run_last_test, "Run last test command")
      map("<localleader>x:", M.java_run_task, "Run build task")
      map("<localleader>ri", M.java_organize_imports, "Organize imports")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(event)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("n", "<localleader>-", M.markdown_insert_horizontal_rule, "Insert horizontal rule")
      map("n", "<localleader>h1", M.markdown_heading(1), "Heading level 1")
      map("n", "<localleader>h2", M.markdown_heading(2), "Heading level 2")
      map("n", "<localleader>h3", M.markdown_heading(3), "Heading level 3")
      map("n", "<localleader>h4", M.markdown_heading(4), "Heading level 4")
      map("n", "<localleader>h5", M.markdown_heading(5), "Heading level 5")
      map("n", "<localleader>h6", M.markdown_heading(6), "Heading level 6")
      map("n", "<localleader>il", M.markdown_insert_link, "Insert link")
      map("n", "<localleader>ii", M.markdown_insert_image, "Insert image")
      map("n", "<localleader>if", M.markdown_insert_footnote, "Insert footnote")
      map("n", "<localleader>iw", M.markdown_insert_wiki_link, "Insert wiki link")
      map("n", "<localleader>iT", M.markdown_insert_table, "Insert table")
      map("n", "<localleader>o", M.markdown_follow_thing, "Follow thing at point")
      map("n", "<localleader>cp", M.markdown_preview, "Preview rendered buffer")
      map("n", "<localleader>cP", M.markdown_toggle_render, "Toggle rendered view")
      map("n", "<localleader>cr", M.markdown_render_buffer, "Render buffer")
      map("n", "<localleader>xB", M.markdown_insert_checkbox, "Insert checkbox")
      map("n", "<localleader>xb", M.markdown_bold, "Insert bold")
      map("x", "<localleader>xb", M.markdown_bold_visual, "Bold selection")
      map("n", "<localleader>xi", M.markdown_italic, "Insert italic")
      map("x", "<localleader>xi", M.markdown_italic_visual, "Italic selection")
      map("n", "<localleader>xc", M.markdown_code, "Insert code")
      map("x", "<localleader>xc", M.markdown_code_visual, "Code selection")
      map({ "n", "x" }, "<localleader>xq", M.markdown_blockquote, "Blockquote")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "terraform", "terraform-vars" },
    callback = function(event)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("n", "<localleader>cc", M.terraform_validate, "Validate project")
      map("n", "<localleader>cl", M.terraform_lint, "Lint project")
      map("n", "<localleader>=c", M.terraform_fmt_check, "Check formatting")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "bash", "sh", "zsh" },
    callback = function(event)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = event.buf,
          desc = desc,
          silent = true,
        })
      end

      map("n", "<localleader>i!", M.shell_insert_shebang, "Insert shebang")
      map("n", "<localleader>ic", M.shell_insert_case, "Insert case statement")
      map("n", "<localleader>ii", M.shell_insert_if, "Insert if statement")
      map("n", "<localleader>if", M.shell_insert_function, "Insert function")
      map("n", "<localleader>io", M.shell_insert_for, "Insert for loop")
      map("n", "<localleader>ie", M.shell_insert_indexed_for, "Insert indexed for loop")
      map("n", "<localleader>iw", M.shell_insert_while, "Insert while loop")
      map("n", "<localleader>ir", M.shell_insert_repeat, "Insert repeat loop")
      map("n", "<localleader>is", M.shell_insert_select, "Insert select loop")
      map("n", "<localleader>iu", M.shell_insert_until, "Insert until loop")
      map("n", "<localleader>ig", M.shell_insert_getopts, "Insert getopts loop")
      map("n", "<localleader>\\", M.shell_add_backslashes, "Append backslashes")
      map("x", "<localleader>\\", M.shell_add_backslashes_visual, "Append backslashes")
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "gitrebase",
    callback = function(event)
      local buf = event.buf
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = buf,
          desc = desc,
          silent = true,
        })
      end

      -- Core actions reuse the built-in gitrebase ftplugin's -range commands:
      -- normal mode acts on the current line, visual mode on the selection.
      -- Letters mirror magit's git-rebase-mode (pick = c; p stays a vim motion).
      local actions = {
        c = "Pick",
        r = "Reword",
        e = "Edit",
        s = "Squash",
        f = "Fixup",
        d = "Drop",
      }
      for key, cmd in pairs(actions) do
        map("n", "<localleader>" .. key, "<Cmd>" .. cmd .. "<CR>", cmd)
        map("x", "<localleader>" .. key, ":" .. cmd .. "<CR>", cmd) -- ':' prefills "'<,'>"
      end

      -- Less-common directives are not provided by the ftplugin, so insert them as
      -- new lines below the current commit. Letters mirror magit; arg-taking ones
      -- drop into insert mode to type the command/label/ref inline.
      local inserts = {
        { key = "x", directive = "exec", arg = true },
        { key = "b", directive = "break", arg = false },
        { key = "l", directive = "label", arg = true },
        { key = "t", directive = "reset", arg = true },
        { key = "M", directive = "merge", arg = true },
        { key = "u", directive = "update-ref", arg = true },
      }
      for _, ins in ipairs(inserts) do
        map("n", "<localleader>" .. ins.key, function()
          M.gitrebase_insert(ins.directive, ins.arg)
        end, "Insert " .. ins.directive)
      end

      local move_up = function()
        M.gitrebase_move(-1)
      end
      local move_down = function()
        M.gitrebase_move(1)
      end
      map("n", "<localleader>k", move_up, "Move commit up")
      map("n", "<localleader>j", move_down, "Move commit down")
      -- magit-style synonyms for moving the commit line
      map("n", "<M-p>", move_up, "Move commit up")
      map("n", "<M-Up>", move_up, "Move commit up")
      map("n", "<M-n>", move_down, "Move commit down")
      map("n", "<M-Down>", move_down, "Move commit down")

      map("n", "<localleader><CR>", M.gitrebase_show_commit, "Show commit")
      -- pick takes ,c, so finish/abort move to their own prefix (magit keeps these
      -- in with-editor as C-c C-c / C-c C-k, not in git-rebase-mode-map).
      map("n", "<localleader>qq", M.gitrebase_finish, "Apply rebase")
      map("n", "<localleader>qa", M.gitrebase_abort, "Abort rebase")

      -- Override the global localleader group labels (compile/refactor/errors/flow/
      -- execute/backend/test/workspace) with buffer-local leaves so the which-key
      -- menu reads correctly and keys fire on first press without a prefix wait.
      shared.register_git_editor_labels(buf, {
        { "<localleader>c", desc = "pick", buffer = buf },
        { "<localleader>r", desc = "reword", buffer = buf },
        { "<localleader>e", desc = "edit", buffer = buf },
        { "<localleader>s", desc = "squash", buffer = buf },
        { "<localleader>f", desc = "fixup", buffer = buf },
        { "<localleader>d", desc = "drop", buffer = buf },
        { "<localleader>x", desc = "exec", buffer = buf },
        { "<localleader>b", desc = "break", buffer = buf },
        { "<localleader>l", desc = "label", buffer = buf },
        { "<localleader>t", desc = "reset", buffer = buf },
        { "<localleader>M", desc = "merge", buffer = buf },
        { "<localleader>u", desc = "update-ref", buffer = buf },
        { "<localleader>k", desc = "move up", buffer = buf },
        { "<localleader>j", desc = "move down", buffer = buf },
        { "<localleader><CR>", desc = "show commit", buffer = buf },
        { "<localleader>q", group = "finish", buffer = buf },
        { "<localleader>qq", desc = "apply rebase", buffer = buf },
        { "<localleader>qa", desc = "abort rebase", buffer = buf },
      })
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "gitcommit",
    callback = function(event)
      local buf = event.buf
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, {
          buffer = buf,
          desc = desc,
          silent = true,
        })
      end

      -- Match the gitrebase finish/abort keys for muscle memory. Uses window-close
      -- semantics (see M.gitcommit_finish) so it is safe in Neogit's in-session
      -- commit editor, which shares the gitcommit filetype.
      map("<localleader>qq", M.gitcommit_finish, "Commit")
      map("<localleader>qa", M.gitcommit_abort, "Abort commit")

      shared.register_git_editor_labels(buf, {
        { "<localleader>q", group = "finish", buffer = buf },
        { "<localleader>qq", desc = "commit", buffer = buf },
        { "<localleader>qa", desc = "abort commit", buffer = buf },
      })
    end,
  })
end

return M
