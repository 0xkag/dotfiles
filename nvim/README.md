# Neovim Migration Notes

This configuration is a Spacemacs-style Neovim setup centered on modal editing,
leader-key discovery, LSP, search, git, tests, terminals, and writing support.

For Python debugging tradeoffs and future DAP notes, see
[DEBUGGING_PYTHON.md](./DEBUGGING_PYTHON.md:1).

For diagnosing main-thread hangs and other Neovim performance problems (with
reusable profiling and LSP-probe recipes), see
[DEBUGGING_NVIM.md](./DEBUGGING_NVIM.md:1).

For deferred decisions around remote editing and Org-style literal runbooks,
see [REMOTE_AND_RUNBOOK_NOTES.md](./REMOTE_AND_RUNBOOK_NOTES.md:1).

For picker-stack and future fzf-integration notes, see
[PICKER_NOTES.md](./PICKER_NOTES.md:1).

For FreeBSD-specific Neovim install notes, see
[FREEBSD_NOTES.md](./FREEBSD_NOTES.md:1).

For the reflow/restyle model behind `gq` / `gQ` / `,=`, see
[FORMATTING_NOTES.md](./FORMATTING_NOTES.md:1).

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
- completion defaults to quiet auto-popup after a 1 second pause
- `Tab` / `Shift-Tab` select completion items or move through snippets
- `Enter` confirms only an explicitly selected completion item
- `Esc` or `Ctrl-g` aborts completion when the popup menu is open
- `fd` exits insert mode
- `Y` yanks to end of line
- `gl` and `gL` align text
- global `textwidth` is `78`

## Main leader groups

- `SPC b` buffers
- `SPC c` code and LSP
- `SPC d` debugging
- `SPC e` errors and diagnostics
- `SPC f` files
- `SPC f e` config files
- `SPC g` git
- `SPC j` jump
- `SPC m` multiple cursors
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
- `:NvimDeps current` also reports the current buffer's missing Treesitter parser
- `:PyenvInfo` show the Python environment Neovim resolved for the current buffer
- `:Org help` view orgmode help
- `:TSInstall lua python markdown markdown_inline org kulala_http` install parsers you want
- Treesitter parser auto-install is off by default; set `vim.g.nvim_treesitter_auto_install = true` before plugin setup if you want startup to ensure the configured parser list
- `:checkhealth` inspect Neovim health

## Syntax checking

- `SPC cf` formats the current buffer on demand
- `SPC el` lint the current buffer
- `SPC eL` open diagnostics in the location list
- Automatic linting is enabled on read and write when a supported linter exists
- Current machine support includes `shellcheck`, `yamllint`, `ruff`, `mypy`, fallback `pylint` or `flake8`, and `tflint`
- completion popup navigation also works with the `Up` and `Down` arrow keys

## Formatting

- `<leader>cf` / `SPC c f` formats the current buffer via conform.nvim
- `<localleader>=b` / `,=b` is the same format-buffer action in the major-mode map
- `<localleader>=r` / `,=r` restyles the current visual selection, then drops it
  (vanilla `gq` behavior); `gv` reselects the reflowed extent and `<localleader>=v`
  / `,=v` restores the exact original selection
- `gQ` / `gQQ` and `<localleader>=q` / `,=q` always restyle (run the formatter),
  regardless of the current reflow mode
- `<localleader>=t` / `,=t` cycles the session reflow mode that drives `gq`
- `<localleader>=v` / `,=v` reselects the exact pre-op selection (mode + columns)
  of the last visual reflow/restyle
- Nothing auto-formats on save; formatting is always explicit
- Formatter selection is per-filetype in `lua/plugins/python.lua` `formatters_by_ft`:
  - Python is a function that probes availability at call time: `ruff_organize_imports` + `ruff_format` when ruff is on `PATH`, falling back to `black` then `yapf`
  - Shell uses `shfmt`; Go uses `gofmt` + `goimports`; JavaScript/TypeScript/JSON/Markdown/YAML use `prettierd` then `prettier`; Lua uses `stylua`; Rust uses `rustfmt`; Terraform uses `terraform_fmt`; TOML uses `taplo`
- `:ConformInfo` shows which formatters conform sees for the current buffer

### `gq` vs `gQ` / `<localleader>=`

Two different jobs -- reflow (structure-preserving) and restyle (authoritative):

- **`gq` / `gqq`** -- reflow per the session **reflow mode** (default
  `builtin` = Neovim's built-in text formatter). Built-in reflow rewraps prose
  and comment blocks to `textwidth`, honoring `formatoptions` and the buffer's
  comment leader (`#`, `//`, etc.), exactly like plain Vim. With the default
  mode, `gq` muscle memory is unchanged. Reach for it to rewrap a long comment
  or a commit-message paragraph to the column guide.
- **`gQ` / `gQQ`** and **`<localleader>=q` / `,=q`** -- always restyle:
  language-aware formatting via conform/LSP (terraform fmt, ruff, prettier,
  ...), regardless of the reflow mode. Reach for it to reformat code structure,
  not just rewrap text. `gQ` replaces stock Vim's Ex-mode entry, which is still
  reachable via `Q`.
- **`<localleader>=b`** restyles the whole buffer; **`<localleader>=r`**
  restyles the visual selection, then drops it (vanilla `gq` behavior).

After a visual-mode reflow (`gq` / `gQ` / `,=q` / `,=r`), the selection is
dropped -- exactly like vanilla Vim's `gq`. The operated extent is recorded as
the last-visual selection, so `gv` reselects it (always linewise). On the reflow
path this is the real wrapped extent (via the `'[` / `']` change marks): if a
2-line block wraps to 3 lines, `gv` selects all 3; if several lines join into
one, `gv` selects the single line. On the restyle path `gv` reselects the
original lines, because conform formats asynchronously and the edited extent is
not known when the mapping returns. To get the *exact* original selection back
(its mode and columns -- a charwise `v` stays charwise), use `<localleader>=v` /
`,=v`, which restores the stashed pre-op selection; reflow overwrites the
`'<` / `'>` marks, so `gv` alone cannot recover it.

The session reflow mode is cycled with `<localleader>=t` / `,=t`, in the order
`builtin` -> `lsp` -> `smart` -> `conservative` -> `builtin`:

- `builtin` -- built-in reflow (the default; today's behavior).
- `lsp` -- conform/LSP restyle.
- `smart` -- treesitter-detected: comment/string nodes reflow, code restyles.
- `conservative` -- autopep8 for Python (fix-violations-only, preserves
  already-compliant code); other filetypes restyle normally via conform, and
  Python falls back to built-in reflow if autopep8 is unavailable.

The split is deliberate. In Neovim, two things otherwise capture `gq`:

- Any attached LSP client sets `formatexpr=v:lua.vim.lsp.formatexpr()`, which
  reroutes `gq` through the server's range formatter. Most servers only re-indent
  code and never reflow comments to `textwidth`, so `gq` silently does nothing.
- `nvim-treesitter` sets `indentexpr`, which recomputes each reflowed line's
  indent and drops comment-continuation lines to column 0.

The reflow maps in `lua/config/reflow.lua` route through `operatorfunc` and
blank both `formatexpr` and `indentexpr` for the duration of a built-in reflow,
so `gq` behaves like it does in plain Vim regardless of which LSP is attached.
(This is why the column guide could look right while `gq` misbehaved --
`colorcolumn` is an independent option.) For more detail see
[FORMATTING_NOTES.md](./FORMATTING_NOTES.md:1).

## Refactoring

- `<leader>cr` / `<localleader>rr` / `SPC c r` opens a scope picker for renaming the symbol under the cursor
- `<leader>ca` / `<localleader>aa` opens the full LSP code action menu
- `<localleader>ar` opens a filtered `refactor` action menu; `<localleader>af` opens `quickfix`; `<localleader>as` opens `source`
- `<localleader>=o` explicitly applies `source.organizeImports`

### Rename scopes

The rename dispatcher offers four scopes via `vim.ui.select`:

| Scope | Backend | Behavior |
|---|---|---|
| Line (multicursor) | multicursor.nvim | Cursors on every matching identifier on the current line; type to edit all at once |
| Function (multicursor) | multicursor.nvim + Treesitter | Cursors on matches inside the enclosing `function_definition` / `function_declaration` node |
| Buffer (multicursor) | multicursor.nvim | Cursors on every match in the whole buffer |
| Workspace (LSP) | `textDocument/rename` | AST-aware rename across all files the LSP knows about |

Multicursor scopes match by identifier string (not AST). A `foo` inside a comment within the same function still gets a cursor. For true AST-local rename use the Workspace scope — pyright is AST-aware even for locals inside one function.

Workspace mode has two UX variants controlled by `vim.g.rename_inc_preview` (default `true`):

- `true` — inc-rename.nvim primes the cmdline with `:IncRename <cword>`; edit the name and watch live substitution highlight every reference in the visible buffer as you type, then `<CR>` applies across the workspace. The dispatcher uses `nvim_feedkeys` (not `vim.cmd`) so the command is editable — calling `vim.cmd("IncRename foo")` would execute immediately and rename the symbol to itself
- `false` — snacks.nvim input float prompts for the new name; a confirm-list (`Apply N edits across M files: [list]`) requires explicit approval before edits land

Toggle with `<leader>tR`. Matches spacemacs `SPC s e` iedit feel for the in-buffer scopes.

Workspace rename routes to pyright even though pylsp is also attached. pylsp advertises `renameProvider` for every plugin slot regardless of whether the plugin is enabled in settings, so a naive `vim.lsp.get_clients({ method = "textDocument/rename" })` would hand the request to pylsp, which then returns nil (no rename plugin is actually wired up). Two things prevent this:

- pylsp's `on_attach` in `lua/plugins/lsp.lua` strips `renameProvider`, `hoverProvider`, `definitionProvider`, `referencesProvider`, `documentSymbolProvider`, `workspaceSymbolProvider`, `completionProvider`, `signatureHelpProvider`, `declarationProvider`, `typeDefinitionProvider`, `implementationProvider`, and `documentHighlightProvider` from `client.server_capabilities` after attach. Only `codeActionProvider` is left, matching pylsp's actual job (rope refactors)
- `rename_with_preview` additionally prefers a client named `pyright` when multiple rename-capable clients remain, as belt-and-suspenders for non-Python stacks that might add another rename provider

If you add a new pylsp plugin that provides one of the stripped capabilities, remove the matching line from `on_attach` and restart the LSP.

### UI

- snacks.nvim `input` module replaces `vim.ui.input` (styled float, no lingering cmdline prompt)
- telescope-ui-select still owns `vim.ui.select`, so the scope picker and confirm-list use telescope

### Python refactoring stack

Python buffers attach three LSPs with a clear division of labor. Overlapping features are disabled so each server owns exactly one responsibility:

| Server | Role | Disabled features |
|---|---|---|
| pyright | types, hover, completion, go-to-def, rename | — |
| pylsp | rope refactoring code actions only | all features except `codeActionProvider` disabled (see `on_attach` in `lua/plugins/lsp.lua`) |
| ruff (server) | lint autofixes + `source.organizeImports` / `source.fixAll` | autoconfig defaults |

**Scope-aware rename of a local**: pyright's LSP rename is AST-aware. Renaming a variable bound only inside one function does not touch same-name identifiers in other scopes. Use `<leader>cr`.

**Rope refactorings** (surfaced under `<localleader>ar`): extract method, extract variable, inline method, inline variable, inline parameter, introduce parameter, move to module, use function, method-to-method-object, local-to-field, generate (variable / function / class / module / package). First rope code action in a session is slow because rope builds the project index; subsequent calls are fast.

**Ruff server code actions** (surfaced under `<localleader>af`): remove unused import, convert to f-string, and any other ruff auto-fix. `source.fixAll` is also available in the full `<leader>ca` menu, and ruff provides `source.organizeImports` under `<localleader>=o`.

### Installing pylsp + pylsp-rope

Not auto-installed. Recommended path:

```
pipx install python-lsp-server
pipx inject python-lsp-server pylsp-rope
```

If a project's pyenv already has `python-lsp-server` + `pylsp-rope` installed, Neovim uses that project's direct `bin/pylsp` before the pipx fallback. Rope then sees the project's installed deps, which can improve cross-file refactoring accuracy. To set this up inside a project venv: `pip install python-lsp-server pylsp-rope`.

`:NvimDeps current` checks the same resolved `pylsp` path that LSP startup uses and warns if either piece is missing. Ruff is already on PATH via flox.

### Python LSP footprint

Steady-state RAM per Python buffer is roughly:

- pyright: 200-400 MB (TypeScript, Node.js)
- pylsp: 100-200 MB (Python; rope index builds lazily on first code action)
- ruff server: 30-50 MB (Rust)

About **350-650 MB total** for the LSP stack. Subprocess spawns per save/read: mypy via `nvim-lint` (1-3 s, independent of LSPs); conform runs `ruff_format` + `ruff_organize_imports` on `<SPC cf>` (50-100 ms each). Ruff diagnostics are **not** spawned per save anymore — they come from the ruff LSP server.

First-attach latency is ~1-2 s to warm all three LSPs in the background; the cursor is never blocked (thanks to the earlier `ipdb` probe fix). Rope's project index builds on first code action per session, not per attach.

If memory pressure becomes a concern, drop pylsp first — it is only required for refactoring and can be disabled in `lua/plugins/lsp.lua` until needed. Pyright's `diagnosticMode = "openFilesOnly"` is already set to limit its workspace scan, which helps on NFS homedirs.

## Completion and signature help

- Completion defaults to quiet auto mode: no ghost text, no first-item preselect, and a 1 second debounce before the popup opens while typing
- Trigger completion immediately with `<C-Space>`
- Confirm the current selection with `<Tab>` or `<CR>` only after you explicitly select an item
- Navigate candidates with `<Down>` / `<Up>` or `<C-n>` / `<C-p>`
- `<CR>` inserts a newline when no completion item is selected
- `<S-Tab>` selects the previous completion item when the menu is visible, otherwise it jumps back through snippet placeholders
- `<Esc>` and `<C-g>` abort the completion popup
- `<leader>ta` / `SPC t a` toggles between quiet-auto and manual completion
- `<leader>tA` / `SPC t A` disables or enables completion for the current buffer; completion is disabled by default on `gitcommit` buffers so commit-message editing stays clean
- `<leader>tM` / `SPC t M` cycles quiet-auto, manual, and full-auto modes. Full-auto restores ghost text and a short popup debounce for temporary aggressive completion
- `<leader>th` / `SPC t h` toggles automatic signature popups for this session
- `:NvimCompletionMode quiet|manual|full` sets the session completion mode directly
- `:NvimCompletionDelay 1.5` sets quiet-auto delay in seconds for this session
- Argument / signature help uses the native `vim.lsp.buf.signature_help` float, which highlights the active parameter as you type
  - `<C-k>` opens the signature-help float in both insert and normal mode
  - `SPC m h s` (`<localleader>hs`) also opens it in normal mode
  - Automatic signature help is off by default; when enabled, it fires on `(` only, not on every comma
  - Signature help floats are non-focusable and close on cursor movement, so they should not require `:q`
- Expand a function call with placeholders using LSP signature data; Tab jumps through placeholders:
  - Positional form, `<localleader>ia` (normal), yields `foo(arg1, arg2='default', ...)` using each parameter's name plus default value (type annotations stripped)
  - Kwargs form, `<localleader>ik` (normal), yields `foo(arg1=arg1, arg2=arg2, ...)` for passing matching local variables by keyword. Skips positional-only params and `*args`/`**kwargs`
  - If the cursor is inside empty `()` the placeholders fill in between the parens; otherwise they are wrapped in a new `(...)`
  - Overloaded functions prompt via `vim.ui.select` to pick a signature
  - If no signature is available, temporary parens inserted for lookup are rolled back so the buffer is left unchanged
  - After expansion Neovim enters SELECT mode (`-- SELECT --` in the mode line) on the first placeholder; this is LuaSnip default IDE-style behavior. Type any character to replace the placeholder, `<Tab>` to keep the default and jump to the next, `<S-Tab>` for previous, `<Esc>` to exit the snippet session
- The completion popup and all floating windows (hover, signature help) use custom highlights under cyberpunk:
  - Dark `#1a1a1a` panel background with `#d3d3d3` text
  - Pink `#7f073f` selection bar; matched characters in yellow
  - Kind column colored per symbol type (functions in pink, types in green, keywords in blue)
  - Active signature parameter highlighted in yellow bold underline
- The statusline is pinned to a cyberpunk-matched palette in `lua/plugins/ui.lua`; switching to another colorscheme leaves it looking cyberpunk — adjust there if that ever matters
- Other colorschemes get sensible fallbacks for Cmp groups automatically via a `ColorScheme` autocmd that links unset `CmpItemKind*` and `LspSignatureActiveParameter` to built-in highlights (`Function`, `Identifier`, `Type`, `Keyword`, `Search`, ...)
- To tweak the cyberpunk palette edit `colors/cyberpunk.lua`; to change the fallback rules edit `apply_cmp_fallbacks` in `lua/config/autocmds.lua`

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

### Pyright diagnostic mode

- Default is `openFilesOnly`: pyright type-checks only buffers you have open
- Closed files are still parsed for import resolution and cross-file features (go-to-definition, hover, rename, find-references) — only their diagnostics are suppressed
- `openFilesOnly` is the default so that opening a Python file in a large repo is fast; `workspace` mode forces pyright to index and type-check every `.py` on first attach, which can freeze the UI for 5-10s on large trees
- Run `:PyrightWorkspaceMode` to flip the active session to `workspace` diagnostics (e.g. before a refactor or pre-commit sweep); it stays until the pyright client restarts
- To make `workspace` the default, edit `diagnosticMode` in `lua/config/python.lua` `pyright_settings`

### Pyenv activation on buffer open

- Opening a `*.py` or `*.pyi` buffer runs `M.activate` in `lua/config/python.lua`, which:
  - Walks upward from the buffer directory looking for `.python-version` (stops at `$HOME`)
  - Calls `pyenv prefix <version>` synchronously via `vim.system():wait()` (roughly 40ms cold, cached per version thereafter)
  - Prepends the resolved `bin/` to `PATH` and sets `VIRTUAL_ENV`
- The sync call is deliberate: formatters, linters, and pyright spawned afterward need `PATH` and `VIRTUAL_ENV` correct before they start, and racing makes the first lint/format after open flaky
- If `pyenv` is not on `PATH` or `.python-version` reads `system`, no activation happens and the system Python is used

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
  - `,o` opens the file or module path named under the cursor (see below)
- Git rebase (the `gitrebase` todo buffer from `git rebase -i`, including Neogit's rebase):
  - letters mirror magit's git-rebase-mode under the localleader prefix
  - `,c`, `,r`, `,e`, `,s`, `,f`, `,d` set the current line (or visual selection) to pick, reword, edit, squash, fixup, or drop
  - `,x`, `,b`, `,l`, `,t`, `,M`, `,u` insert an exec, break, label, reset, merge, or update-ref directive below the current commit (arg-taking ones drop into insert mode)
  - `,k` / `,j` move the commit under the cursor up or down to reorder it; `<M-p>` / `<M-Up>` and `<M-n>` / `<M-Down>` are magit-style synonyms
  - `,<CR>` shows the commit under the cursor in a split (`q` closes it)
  - `,qq` writes the todo list and applies the rebase; `,qa` aborts it
  - built-in `<C-A>` / `<C-X>` still cycle the action, and `:wq` / `ZZ` still finish
- Git commit (the `gitcommit` message buffer from `git commit`, also Neogit's commit editor and rebase `reword` steps):
  - `,qq` writes the message and commits; `,qa` empties the message and aborts the commit
  - keys match the rebase finish/abort for muscle memory; uses window-close (not quit-all) so it is safe inside Neogit's in-session editor
  - native `:wq` / `:cq` still work

### Terraform: open file/module under cursor (`,o`)

In terraform buffers, `,o` jumps to the file or module whose path is named
under the cursor (`lua/config/code_mode/terraform.lua`, bound in the terraform
`FileType` block in `lua/config/code_mode/init.lua`). It resolves, in order:

1. The string under the cursor is read via treesitter (walking to the
   outermost `quoted_template`, so a `${...}` prefix is not dropped), falling
   back to `<cfile>` if no string node is found.
2. Path references are expanded: `${path.module}` to the current file's
   directory, and `${path.root}` / `${path.cwd}` to the project root
   (`util.project_root`). A string that still contains an unresolved
   interpolation (e.g. `${var.name}`) is skipped, since the real path is only
   known at plan time.
3. The path is resolved against the module directory first, then the project
   root. A path that resolves to a **file** is opened directly (e.g. a
   `templatefile(...)` / `file(...)` argument). A path that resolves to a
   **directory** is a module `source`, so its entry file is opened: `main.tf`,
   else the first `*.tf` alphabetically, else the directory itself.
4. If nothing resolves locally, it falls back to following an LSP
   `textDocument/documentLink` under the cursor, then notifies if there is
   still nothing.

This is the only way to follow `templatefile`/`file` path arguments, which are
plain strings the LSP does not track. For module `source` values it overlaps
with `,gg` (LSP go-to-definition, which terraform-ls also resolves to the
module) — both land in the right place; `,o` additionally works when no LSP is
attached. Built-in `gf` is not sufficient here because it cannot expand
`${path.module}`.

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
- Prefer installing tools on your normal `PATH` (flox, system package manager, language toolchains) so other tools can use them too
- Use `:Mason` only when you want Neovim-managed installs, isolated to `~/.local/share/nvim/mason/`
- `:MasonInstall` and related Mason commands are available directly even in a fresh lazy-loaded session

### Using Mason

- `:Mason` opens the UI; inside:
  - `i` install the package under the cursor
  - `X` uninstall
  - `u` update the package under the cursor, `U` update all
  - `/` filter, `1`-`7` switch category tabs (LSP / DAP / Linter / Formatter)
  - `g?` shows the full keymap
- `:MasonInstall <pkg1> <pkg2> ...` installs non-interactively
- `:MasonUpdate` refreshes the package registry
- `:checkhealth mason` validates the install
- Mason downloads prebuilt binaries; on systems with an old glibc (e.g. Amazon Linux 2), some binaries fail to load — fall back to flox or source builds

### Common dependency check warnings

The warnings shown on startup come from `lua/config/deps.lua`. The binary names in the warning map to these Mason packages:

| Warning (binary)                 | Mason package                  |
|----------------------------------|--------------------------------|
| `clangd`                         | `clangd`                       |
| `jdtls`                          | `jdtls`                        |
| `typescript-language-server`     | `typescript-language-server`   |
| `prettierd` / `prettier`         | `prettierd` / `prettier`       |
| `vscode-html-language-server`    | `html-lsp`                     |
| `vscode-json-language-server`    | `json-lsp`                     |
| `vscode-css-language-server`     | `css-lsp`                      |
| `bash-language-server`           | `bash-language-server`         |
| `yaml-language-server`           | `yaml-language-server`         |
| `marksman`                       | `marksman`                     |
| `lua-language-server`            | `lua-language-server`          |
| `stylua`                         | `stylua`                       |
| `shfmt` / `shellcheck`           | `shfmt` / `shellcheck`         |
| `terraform-ls` / `tflint`        | `terraform-ls` / `tflint`      |
| `rust-analyzer` / `rustfmt`      | `rust-analyzer` (rustfmt via rustup) |
| `gopls` / `goimports`            | `gopls` / `goimports`          |

Bulk install example for a typical frontend + backend workstation:

```
:MasonInstall html-lsp json-lsp css-lsp typescript-language-server prettierd clangd gopls goimports
```

### Trimming startup warnings

- `startup_features` in `lua/config/deps.lua` controls which checks fire on Neovim startup
- Remove entries for languages you never use to silence their warnings; per-filetype checks still fire when opening a matching file
- `filetype_features` in the same file maps filetype to the checks that run on first buffer open

## LSP performance in large repos

Opening many files from a large monorepo (e.g. a few hundred `.tf` files in a
tree with tens of thousands of directories) used to pin a CPU core and lock up
Neovim. Two unrelated main-thread hazards are handled here.

### Semantic-token guard

The lockup was a malformed semantic token. terraform-ls can send a token whose
`deltaStart` is a small negative delta encoded as an unsigned 32-bit int (e.g.
`4294967253`, which is `2^32 - 43`). Neovim's
`runtime/lua/vim/lsp/semantic_tokens.lua` then computes an astronomical
end-of-token column and spins its range-extension loop billions of times on the
main thread, ignoring even SIGTERM.

`lua/config/lsp_semantic_guard.lua` wraps `STHighlighter:process_response` and
clamps each token's `deltaStart` and `length` to the buffer's longest line
before that loop runs. The LSP spec forbids a token from spanning lines, so
valid tokens are untouched; only the malformed value is bounded. It is applied
globally for every server in `lua/plugins/lsp.lua`, degrades to a no-op if the
runtime internals change, and leaves semantic highlighting fully enabled. This
is a workaround for an upstream Neovim bug, not a feature toggle: semantic
tokens still color buffers normally on top of treesitter.

### LSP file watching

When a server registers `workspace/didChangeWatchedFiles` and no native
file-watch backend is available, Neovim falls back to a pure-Lua `watchdirs`
walk that creates one watch handle per directory on the main thread. In a huge
workspace that walk is itself expensive.

- On macOS/Windows Neovim uses an efficient native recursive watcher, and when
  `inotifywait` (from `inotify-tools`) is on `PATH` it watches via an
  off-main-thread subprocess. In both cases watching is left fully enabled.
- Otherwise (the `watchdirs` backend) `lua/config/lsp_watch.lua` declines the
  watcher for a client only when its workspace tree is huge, and installs a
  single `.git/HEAD` watch so a branch switch still triggers an `:LspRestart`
  to refresh the server. The only thing lost is live detection of external
  changes between branch switches (e.g. a `terraform init` writing
  `.terraform/modules` while Neovim is open); `:LspRestart` refreshes manually.
- The `file_watch` dependency check warns once on startup (and in `:NvimDeps`)
  when no native backend is available, recommending `inotify-tools`
  (`inotify-tools port` on FreeBSD). Install it on your normal `PATH` (flox,
  system package manager) rather than via Mason: it is a system tool, not a
  language server.

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

## Testing

- Config logic with non-trivial behavior has headless specs under `nvim/test/`,
  named `*_spec.lua`
- Run them all with `nvim/test/run.sh`; it runs each spec headless and exits
  nonzero if any fail
- Run specific specs by name, e.g. `nvim/test/run.sh reflow` for
  `nvim/test/reflow_spec.lua`
- Each spec is self-contained (`nvim --headless -u NONE -l <spec>`): it sets its
  own `package.path`, requires the module under test, prints `ok` / `FAIL` lines,
  and calls `cquit 1` on failure so the runner sees a nonzero exit
- Current specs cover the pure logic that backs the keymaps: `reflow_spec`
  (`config.reflow`), `util_spec` (root/grep/global parsers, visual selection,
  whitespace squeeze), `completion_spec` (the completion mode state machine),
  `code_mode_spec` (Go/Java/Python test-target detection, indentation, shell
  template rendering), and `lsp_util_spec` (signature-label and workspace-edit
  helpers)
- The language helpers behind `config.code_mode` live in per-language
  submodules under `lua/config/code_mode/` (`go`, `java`, `markdown`, `shell`,
  `python_debug`, `terraform`, `git_editor`, plus `shared`); when adding a pure
  helper there, expose it (or an `_`-prefixed test seam) and add a spec

## Backlog

Durable guardrails and the still-open work, salvaged from the (now retired)
migration-status tracker. Completed milestones and the original baseline commits
live in git history.

### Guardrails

- Do not enable automatic formatting on save for any language; keep formatting an
  explicit action via `SPC c f` (conform) or `:ConformInfo`
- Keep `:NvimDeps` reporting explicit — surface missing tools rather than
  auto-installing them

### Open alignment checks

- Keep auditing code-mode `SPC m` and `,` bindings against Spacemacs defaults;
  more localleader parity checks may still be useful
- Keep checking localleader `which-key` coverage in filetype-specific buffers so
  `,` stays discoverable everywhere it matters
- Review the old `~/.dotfiles/vim` config behavior-by-behavior and classify each
  as already-matched, intentionally-different, or worth-porting

### Known partial / intentionally deferred

- Spacemacs code-mode parity is partial by choice: advanced Go helpers
  (go-play, graphical coverage, test generation, deep refactors), advanced
  Java generator/refactor actions, and niche Markdown/Terraform actions are
  approximated via LSP or omitted
- Some `lsp-ui`/peek-style overlays are approximated with Telescope/quickfix
- Python debugging is terminal/`ipdb`-oriented rather than a full DAP UI (see
  [DEBUGGING_PYTHON.md](./DEBUGGING_PYTHON.md:1))
- Remote editing is deferred; Oil SSH is the leading future option (`netrw` is
  intentionally disabled) — see
  [REMOTE_AND_RUNBOOK_NOTES.md](./REMOTE_AND_RUNBOOK_NOTES.md:1)
- The legacy clipboard fallback aliases remain disabled reference comments in
  `lua/config/keymaps.lua`; decide later whether to revive them as a toggle
- The Emacs-native long tail is unported: heavy Org integrations, Elfeed, the
  PDF workflow, the IETF/xkcd/speed-reading layers, and some secondary
  language/tooling layers

### Validation baseline

- `nvim --headless '+qa'`
- `nvim --headless '+Lazy! load all' '+qa'`
- `nvim/test/run.sh` passes
- `:NvimDeps` reports all checked dependencies installed
