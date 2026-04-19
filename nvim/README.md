# Neovim Migration Notes

This configuration is a Spacemacs-style Neovim setup centered on modal editing,
leader-key discovery, LSP, search, git, tests, terminals, and writing support.

For Python debugging tradeoffs and future DAP notes, see
[DEBUGGING_NOTES.md](/home/kag/.dotfiles/nvim/DEBUGGING_NOTES.md:1).

For deferred decisions around remote editing and Org-style literal runbooks,
see [REMOTE_AND_RUNBOOK_NOTES.md](/home/kag/.dotfiles/nvim/REMOTE_AND_RUNBOOK_NOTES.md:1).

For picker-stack and future fzf-integration notes, see
[PICKER_NOTES.md](/home/kag/.dotfiles/nvim/PICKER_NOTES.md:1).

## Core keys

- `SPC` is the main leader key
- `,` is the local leader key
- `SPC` and `,` both open `which-key` popups for discoverable mappings
- `SPC SPC` opens searchable commands, similar to a lightweight Spacemacs `SPC SPC`
- `SPC ?` opens searchable keymaps
- Global indentation defaults to 4 spaces; common languages override that explicitly
- `SPC TAB` switches to the alternate buffer
- `SPC /` runs project grep
- `SPC *` searches the current word in the project
- visual `*` and `#` search the current selection forward or backward
- `Ctrl-Space` opens completion
- `Tab` / `Shift-Tab` navigate completion or snippets
- `Enter` confirms completion
- `Esc` aborts completion when the popup menu is open
- `fd` exits insert mode
- `Y` yanks to end of line
- `gl` and `gL` align text
- global `textwidth` is `78`

## Main leader groups

- `SPC b` buffers
- `SPC c` code and LSP
- `SPC d` debugging
- `SPC e` edit and multiple cursors
- `SPC f` files
- `SPC f e` config files
- `SPC g` git
- `SPC j` jump
- `SPC o` open, org, outline, and terminals
- `SPC p` project
- `SPC q` quit and sessions
- `SPC r` tests
- `SPC s` search
- `SPC t` toggles
- `SPC w` windows
- `SPC y` clipboard

## Project workflow

- `SPC pp` opens the recent-project switcher
- `SPC pr` reopens the same recent-project picker
- `SPC pa` adds the current project to the recent list
- `SPC pd` removes the current project from the recent list
- `SPC pf` finds files in the current project
- `SPC pg` or `SPC p/` greps in the current project
- `SPC pt` opens the project tree
- `SPC od` opens the current directory in Oil
- `SPC oD` opens the project root in Oil
- Project switching saves the current session, changes directory, and restores the target project session when one exists
- In the project picker, `<C-d>` in insert mode or `dd` in normal mode removes the selected project from history

## Useful commands

- `:colorscheme cyberdream`, `:colorscheme ron`, or `:colorscheme cyberpunk`
- `:ThemeReview` opens a Python/Markdown/diff fixture for side-by-side theme checks
- `:Mason` manage language servers
- `:ConformInfo` inspect formatter setup
- `:Neogit` open the git UI
- `:Oil` open a dired-style editable directory buffer
- `:Telescope commands` search commands
- `:Telescope keymaps` search mappings
- `:NvimDeps` show missing configured dependencies on `PATH`
- `:NvimDeps current` show missing dependencies for the current buffer workflow
- `:PyenvInfo` show the Python environment Neovim resolved for the current buffer
- `:Org help` view orgmode help
- `:TSInstall lua python markdown markdown_inline org kulala_http` install parsers you want
- `:checkhealth` inspect Neovim health

## Syntax checking

- `SPC cf` formats the current buffer on demand
- `SPC cl` lint the current buffer
- `SPC cL` open diagnostics in the location list
- Automatic linting is enabled on read and write when a supported linter exists
- Current machine support includes `shellcheck`, `yamllint`, `ruff`, `mypy`, fallback `pylint` or `flake8`, and `tflint`
- completion popup navigation also works with the `Up` and `Down` arrow keys

## Python workflow

- Python files automatically honor a project `.python-version` when `pyenv` is installed
- Pyright is configured with the resolved project interpreter when a `.python-version` is present
- `SPC cp` or `:PyenvInfo` shows the Python environment Neovim is using for the current buffer
- The activated `pyenv` environment is used for Python linting, formatting, and test tools spawned by Neovim
- Formatting is manual only; nothing autoformats on save
- Python linting prefers `ruff` plus `mypy`, then falls back to `pylint`, then `flake8`
- Python formatting prefers `ruff_organize_imports` plus `ruff_format`, then falls back to `black`, then `yapf`
- Python tests run through the same interpreter Neovim resolves for the current project
- Python debugging expects `ipdb` in that same interpreter and reports it through `:NvimDeps current` if it is missing
- `SPC dd` or `,dd` debugs the current file with `python -m ipdb`
- `SPC dt` or `,dt` debugs the nearest pytest test with `pytest --trace`
- `SPC dT` or `,dT` debugs the current test file with `pytest --trace`
- `SPC dl` or `,dl` reruns the last Python debug command

## Navigation

- `s` triggers labeled jump mode
- `S` jumps by Treesitter nodes
- `SPC jj` jumps across visible text
- `SPC jt` jumps by Treesitter nodes
- `SPC jr` performs a remote jump
- `gd` open definitions through Telescope
- `gi` open implementations through Telescope
- `gr` open references through Telescope
- `gy` open type definitions through Telescope
- `SPC ft` toggles the file tree
- `SPC pt` opens the project tree
- `SPC od` opens the current directory in Oil
- `SPC oD` opens the current project root in Oil
- `SPC SPC` searches commands
- `SPC ?` or `SPC s k` searches keymaps
- `SPC cs` document symbols
- `SPC os` toggle the outline sidebar
- Neo-tree remains the tree/sidebar view, while Oil is the dired-style directory editor
- `Ctrl-g` closes most popup/transient UIs such as Telescope, Oil, Neo-tree, and utility windows without becoming a global remap
- Without LSP, `gd` and `gr` fall back to GNU Global when a GTAGS database exists
- `SPC cg` prompts for a GNU Global symbol search
- `SPC pu` updates the GNU Global database for the current project
- In LSP/code buffers, localleader mirrors Spacemacs major-mode navigation:
  - `,gg` definition
  - `,gD` declaration
  - `,gd` type definition
  - `,gb` jump back
  - `,gp` jump back
  - `,gn` jump forward
  - `,ge` buffer diagnostics
  - `,gA` search project types
  - `,gM` document symbols
  - `,gi` implementation
  - `,gr` references
  - `,gR` references alias
  - `,gs` workspace symbols
  - `,gS` all workspace symbols
  - `,gkk`, `,gks`, `,gku` open type hierarchy, subtype hierarchy, and supertype hierarchy
  - `,f<`, `,f>` open incoming and outgoing call hierarchies
  - `,Fa`, `,Fr`, `,Fs` manage and browse LSP workspace folders
  - `,hh` hover/docs
  - `,bd` LSP session info
  - `,ea`, `,el` execute a code action or list project diagnostics
  - `,br`, `,bs`, `,bv` restart, stop, or inspect active LSP clients
  - `,qr` restarts the active workspace
  - `,rr` rename
  - `,aa` code action
  - `,af` fix action
  - `,ar` refactor action
  - `,as` source action
  - `,=b` format buffer manually
  - visual `,=r` format selection
  - `,=o` organize imports
  - `,xh`, `,xl`, `,xL` highlight references and refresh/run code lenses
  - `,Tl` toggles inlay hints when the server supports them
  - in Python buffers, `,tt`, `,tf`, `,tl`, `,ts`, `,to`, `,tO`, `,tx` mirror the test workflow under localleader

## Language localleader

- Python:
  - `,tt`, `,tf`, `,tl`, `,ts`, `,to`, `,tO`, `,tx` run and inspect tests
- Go:
  - `,ga` alternate between source and test
  - `,gc` run a coverage summary for the current package
  - `,ig` jump to imports
  - `,ir` or `,ri` organize imports
  - `,tp`, `,tP`, `,tt`, `,tl` run package, project, nearest, or last tests
  - `,xx` run the current package
  - `,xg`, `,xG` run `go generate` for the file or project
- Java:
  - `,ga` alternate between source and test
  - `,cc` build the project
  - `,ta`, `,tc`, `,tt`, `,tl` run all, class, nearest, or last tests
  - `,x:` runs a Maven or Gradle task
  - `,ri` organizes imports
- Shell:
  - `,i!` inserts a shebang
  - `,ic`, `,ii`, `,if`, `,io`, `,ie`, `,iw`, `,ir`, `,is`, `,iu`, `,ig` insert common shell templates
  - `,\` appends line-continuation backslashes to the current line or visual selection
- Markdown:
  - `,-` inserts a horizontal rule
  - `,h1` through `,h6` set the current line to a heading level
  - `,il`, `,ii`, `,if`, `,iw`, `,iT` insert links, images, footnotes, wiki links, and tables
  - `,xb`, `,xi`, `,xc`, `,xq`, `,xB` add emphasis, code, blockquotes, and checkboxes
  - `,o` follows the thing under the cursor
  - `,cp`, `,cP`, `,cr` preview, toggle, or enable rendered Markdown
- Terraform:
  - `,cc` runs `terraform validate`
  - `,cl` runs `tflint`
  - `,=c` checks formatting with `terraform fmt -check`

## Vim-style editing helpers

- `list` is enabled globally
- `SPC tvt` toggles `list`
- `SPC tva` switches to the old ASCII listchars profile
- `SPC tvu` switches to the old Unicode listchars profile
- wrapped lines show `+++ ` as the `showbreak` marker
- insert mode restores Vim/Emacs crossover keys:
  - `Ctrl-a` line start
  - `Ctrl-e` line end
  - `Ctrl-w` delete word forward
  - `Ctrl-h`, `Ctrl-l` move left and right
- command-line mode restores `Ctrl-a` and `Ctrl-e`
- normal mode keeps the old Vim `Ctrl-a` / `Ctrl-e` home/end remaps
- visual `.` repeats the last change across the selection
- visual `<leader>%` seeds a whole-buffer substitute using the selected text
- `autoread` is enabled
- `textwidth=78` and `formatoptions` include the old Vim `c` and `l` behavior
- dictionary/spelling helpers use `/usr/share/dict/words` when present and `spellsuggest=best,8`
- opening `*.bin` uses the old `xxd` round-trip workflow when `xxd` is installed
- `SPC C` and `SPC Y` provide legacy clipboard yank aliases from the old Vim setup

## Evil Feel

- Surround operations use `nvim-surround`, so `ys`, `cs`, and `ds` work like vim-surround and evil-surround muscle memory
- Visual `*` and `#` search the selected text directly
- Common special buffers now accept both `q` and `<Esc>` to close

## Dependency checks

- On startup, Neovim warns once about missing non-Python tools referenced by this config
- On the first buffer for a supported filetype, Neovim warns once about missing tools for that workflow
- Tool checks treat inactive `mise` shims as missing so false positives do not hide broken commands
- `SPC cm` checks dependencies for the current buffer
- `SPC cM` runs the full configured dependency audit

## LSP installs

- Language servers are not auto-installed by this config
- Missing servers are reported through dependency checks instead of background installation attempts
- Use `:Mason` only when you want Neovim-managed installs, or install servers on your normal `PATH`
- `:MasonInstall` and related Mason commands are available directly even in a fresh lazy-loaded session

## Org defaults

- Agenda files: `~/wc/personal/personal/*.org`
- Default notes file: `~/wc/personal/personal/todo.org`
- Global org actions: `SPC o a` for agenda, `SPC o c` for capture

## HTTP files

- Open a `.http` file and use localleader mappings
- `,r` run request under cursor
- `,a` run all requests in the current buffer
- `,l` replay the last request
- `,o` open the result pane
- `,i` inspect the parsed request
- `,s` show request stats
