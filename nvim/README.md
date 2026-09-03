# Neovim Configuration

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
- The popups spell special key names -- `SPC`, `TAB`, `RET`, `ESC`, `BS`, `C-`, `M-` -- rather than drawing them as pictograms; which-key's defaults put 24 of its 28 key icons in the Material Design Icons block that only exists in Nerd Fonts v3, so on an older patched font they render as tofu, and spelling them also matches the notation this README uses
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
- `fd` exits insert mode; insert mode runs on a 150 ms key timeout so a lone `f` shows up promptly, while normal mode keeps 500 ms for leader chords
- `Y` yanks to end of line, and `[d` / `]d` jump between diagnostics; both are Neovim's own maps, not this config's
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
- `SPC r` run (tests)
- `SPC s` search
- `SPC t` toggles
- `SPC w` windows
- `SPC y` clipboard

## File and picker views

Three components split the work, and it is worth knowing which one you are in:

| Component | What it is | Main keys |
|---|---|---|
| **neo-tree** | Persistent sidebar tree. For *looking*: navigating and seeing structure. | `SPC pe` / `SPC pt`, `SPC oe`, `SPC ft` |
| **Oil** | An editable directory buffer, dired-style. For *changing*: rename a line to rename the file, delete a line to delete it, add a line to create one, then `:w` to apply. One directory at a time, in a normal buffer. | `SPC od`, `SPC oD`, `:Oil`, `<C-l>` to refresh |
| **Telescope** | The picker: a popup of prompt + results + preview. For *finding*. | `SPC pf`, `SPC ff`, `SPC /`, `SPC gc`, `SPC SPC` |

- "Picker" means a Telescope popup. Each is built from a finder (where candidates
  come from), a sorter (how typing filters them), a previewer (the right-hand
  pane), and an entry maker (how one candidate becomes a display line). `<C-h>`
  inside one lists its own mappings.
- All three mark changed files against the same diff base, the one `SPC gm` sets,
  so they agree about what "changed" means.
- They also share one cached listing per repo. It is dropped when the base
  changes, on a write, after a `:!` command, on leaving a terminal, on regaining
  focus, after a gitsigns or Oil mutation, and when neo-tree's own status run
  reports a change; Oil's `<C-l>` drops it by hand. Submodules are compared by
  recorded commit only (`--ignore-submodules=dirty`), which is what makes a
  listing in `~/.dotfiles` cost 9 ms rather than 137.
- The listing runs in the background. A picker or Oil buffer opens at once,
  unmarked if nothing is cached, and is redrawn when the listing lands; an Oil
  buffer holding unsaved edits is left alone, and its marks wait for `<C-l>`.
- Oil is the default file explorer in place of `netrw`, so `:e somedir/` opens it.
- `Ctrl-g` closes all three.
- Two lookalikes that are not Telescope: the small prompt `SPC gM` opens is
  snacks.nvim's `input`, and any `vim.ui.select` menu is routed into Telescope's
  UI by telescope-ui-select.

## Project workflow

- `SPC pp` opens the recent-project switcher
- `SPC pr` reopens the same recent-project picker
- `SPC pa` adds the current project to the recent list
- `SPC pd` removes the current project from the recent list
- `SPC pf` finds files in the current project, each entry marked against the active diff base (`M` modified, `A` added, `D` deleted, `R` renamed, `?` untracked) with the base named in the prompt title, so it agrees with `SPC gc` about what changed
- Those marks appear in any file picker that lands in a git repo (`SPC ff` and `SPC fd` too), and they follow `SPC gm`: at the index base a file committed earlier on the branch is unmarked, against `origin/<default>` it shows as changed
- `SPC pg` or `SPC p/` greps in the current project
- `SPC pt` opens the project tree -- the same action as `SPC pe`, kept as a synonym
- `SPC od` opens the current directory in Oil, `SPC oD` the project root; both carry a git status column marked against the active diff base, the same marks the pickers and the tree use
- Oil's column does *not* redraw itself when `SPC gm` changes the base: an Oil buffer can be holding unsaved filesystem edits and a refresh discards them, so `<C-l>` (Oil's refresh, which also drops the cached listing) is left to you
- Project switching saves the current session, changes directory, and restores the target project session when one exists
- In the project picker, `<C-d>` in insert mode or `dd` in normal mode removes the selected project from history
- The tree marks changed files: `M` modified, `R` renamed, `?` untracked, `*` unstaged, `+` staged, `✚` added, `✖` deleted, bubbled up onto parent directories
- The tree renders in a *plain* profile by default: neo-tree's defaults lean on Nerd Font private-use codepoints for most git marks, the folder icons, the expander arrows, and -- via `icon.provider` on every single file row -- the nvim-web-devicons glyph, all of which arrive as tofu over PuTTY or any unpatched font. Ordinary Unicode is left alone (the box-drawing indent markers, `✚` / `✖`, the symlink arrow), because it renders fine unpatched -- checked in PuTTY + tmux
- `SPC tg` toggles the whole tree between the plain profile and the full Nerd Font set (status marks, folder icons, devicons, expanders); an open tree is closed and re-revealed, because glyphs are resolved as it draws
- Against a ref base the tree also marks what this branch *committed* since that base -- files a `git status` cannot see because the worktree is clean -- in a dimmer `NeoTreeGitBase` highlight, so "already committed" reads differently from "not committed yet" without a second column; a collapsed directory bubbles up a mark when something under it changed
- `]g` / `[g` inside the tree jump to the next and previous changed file over that same set -- worktree changes, untracked files, and anything committed since the base; neo-tree's own versions read its status table, which cannot see the base marks and skips untracked files, so they are replaced
- Worktree status wins where both apply, since not-yet-committed is the more urgent fact; the base marks are recomputed on a tree refresh and whenever `SPC gm` changes the base (an open tree redraws itself), one `git diff` per refresh rather than per row
- Two change sets are in play, on purpose: the tree's base marks come from `git diff <base> HEAD` (what this branch committed), because neo-tree's own status already covers the worktree, while the pickers, Oil, `]g` and `SPC gc` list `<base>..worktree` (everything that differs). Both read the same `--name-status` output, so a row agrees with the picker entry for the same file
- Inside any Telescope picker, `<C-h>` (or Telescope's own `<C-/>`) lists that picker's mappings; they are buffer-local to the prompt buffer, so `SPC ?` and `SPC hk` never show them
- Picker mappings worth knowing: `<C-q>` sends every result to the quickfix list and opens it, `<Tab>` multi-selects and `<M-q>` sends only the selection, `<C-x>` / `<C-v>` / `<C-t>` open in a split, vsplit, or tab, and `q` or `<C-g>` closes

Every glyph the tree can draw, and what the plain profile does with it. The
entries marked `std` are ordinary Unicode and render without a patched font, so
the plain profile keeps them; everything else is a private-use codepoint and
gets replaced:

| Row element | Neo-tree default | Plain profile |
|---|---|---|
| File icon | whatever nvim-web-devicons returns, via `icon.provider` -- on every file row | blank (the provider is dropped, not replaced) |
| Directory closed / open | U+E5FF / U+E5FE | `+` / `-` |
| Directory empty / empty open | U+F0256 / U+F0DCF | `-` / `-` |
| Expander collapsed / expanded | U+F460 / U+F47C | `>` / `v` |
| Indent marker / last | `std` U+2502 / U+2514 | kept -- box drawing needs no patch |
| Symlink arrow | `std` U+279B | kept |
| Status added / deleted | `std` U+271A / U+2716 | kept (`✚` / `✖`) |
| Status modified / renamed | U+F444 / U+F0055 | `M` / `R` |
| Status untracked / ignored | U+F128 / U+F474 | `?` / `I` |
| Status unstaged / staged | U+F0131 / U+F046 | `*` / `+` |
| Status conflict | U+E727 | `!` |

The file icon is deliberately blank: the status column already owns the right of
the row, so anything in the icon column reads as a status too. `*` was the worst
of both, being the unstaged mark as well, so it printed twice on one line with
two meanings. `+` still means "directory closed" on the left and "staged" on the
right; they never share a row, so it is left as is.

## Useful commands

- `:colorscheme cyberdream`, `:colorscheme ron`, or `:colorscheme cyberpunk`
- `:ThemeReview` opens a Python/Markdown/diff fixture for side-by-side theme checks
- `:Mason` manage language servers
- `:ConformInfo` inspect formatter setup
- `:Neogit` open the git UI
- `:Oil` open a dired-style editable directory buffer
- `:Telescope commands` search commands
- `:Telescope keymaps` search mappings
- `:checkhealth config` audits every external tool this config leans on, probed afresh, in two sections (editor-wide, languages); `SPC cM` opens it
- `SPC cm` re-checks the current buffer's workflow tools and its Treesitter parser, and says so when all are present
- `:PyenvInfo` show the Python environment Neovim resolved for the current buffer
- `:Org help` view orgmode help
- `:TSInstall lua python markdown markdown_inline org kulala_http` install parsers you want
- Treesitter parser auto-install is off by default; set `vim.g.nvim_treesitter_auto_install = true` before plugin setup if you want startup to ensure the configured parser list
- `:checkhealth` inspect Neovim health

## Git

Neogit is the magit-equivalent UI; gitsigns drives the gutter, hunks, and blame.

- `SPC gg` open Neogit (status / staging / committing / rebasing)
- `SPC gb` blame the current line in a popup (one-shot, full message)
- `SPC gB` toggle inline current-line blame
- `SPC gl` open the full-file blame buffer; inside it:
  - `r` reblame at the commit under the cursor
  - `R` reblame at that commit's parent (`<hash>^`) to walk back through
    history one change at a time
  - `<CR>` open the context menu, `d` diff in a tab, `s` / `S` show the
    commit (message + diff) in a vsplit / new tab, `q` quit the buffer
  - `o` open the full file at the commit that touched the line under the
    cursor (the whole file as of that revision, not just the commit's diff)
  - the winbar shows this legend; `SPC ex`-style hints are not needed
  - note: `R` repositions the cursor to the same screen line in the
    reblamed file, not the same source line, because the parent revision is
    a different file whose line numbers have shifted (gitsigns clamps the
    old line number to the new buffer rather than following the blamed line)
- `SPC gL` log the current line's history with `git log -L` (`-L` mnemonic),
  in normal mode the line under the cursor and in visual mode the selected
  range; unlike blame's `R` this follows the line as it moves across
  revisions, opening the full history (commit + diff for that line) in a
  scratch tab; also works from inside the blame buffer, where it targets the
  scroll-bound source line; inside the log buffer:
  - `b` open gitsigns' interactive blame at the commit under the cursor, so
    `r` / `R` reblame cycling continues from that revision
  - `o` open the full file at the commit under the cursor
  - `q` quit the buffer; the winbar shows this legend
- `SPC gm` cycle the gutter's diff base: index -> merge-base with the default
  branch (what this branch changed) -> `origin/<default>` (unpushed commits +
  uncommitted) -> index; the first press skips straight to the most useful
  base for the context (`origin/<default>` when on the default branch itself,
  merge-base otherwise)
- `SPC gM` prompt for any ref as the diff base, prefilled with the active (or
  auto-detected) base; empty input resets to the index
- `SPC pf` marks changed files inline; `SPC gc` below is the same base, filtered
  to only what changed
- `SPC gc` project-wide picker of every file changed against the active diff
  base, previewing each file's diff against that base; the base is global but
  the gutter only shows it in files that are already open, so this is the
  whole-project view of the same base. At the index base the list is `git
  status` (staged, unstaged, and untracked); against a ref it is `git diff
  --name-status <ref>` plus the untracked files a diff cannot see, with
  renames listed under their new path; `<C-q>` in the picker turns the list
  into a quickfix list of the changed files
- `SPC gC` project-wide hunk list (one quickfix entry per hunk) from gitsigns'
  own `setqflist("all")` scan, narrowed to the current project's repo -- the
  scan otherwise covers every repo gitsigns knows about, the cwd's plus one
  per attached buffer -- and titled with the active base; untracked files are
  omitted because that scan skips them unless `attach_to_untracked` is on
- an empty `SPC gC` says which of the three causes it was, since gitsigns'
  output cannot distinguish them: no changes at all, only untracked changes
  (which its scan skips), or tracked changes that the scan never reached
  because neither nvim's cwd nor any attached buffer was in the repo -- the
  last case warns and tells you to cd there or open a file from it
- listing a large repo is `git status` at the index base; `git config
  core.untrackedCache true` (and `core.fsmonitor true` where the daemon runs)
  keeps that fast. Submodules are already compared by commit only, which is
  most of the cost in `~/.dotfiles`
- `:GitsignsBase <ref>` diff the gutter against any ref; `:GitsignsBase` with
  no argument resets to the index

## Syntax checking

- `SPC cf` formats the current buffer on demand
- `SPC el` lint the current buffer
- `SPC eL` open diagnostics in the location list
- `SPC ex` shows the diagnostic under the cursor in a float on demand
- Inline diagnostic messages use a hover float, not virtual text: the
  diagnostic under the cursor is shown automatically on `CursorHold` (after
  `updatetime`, 200ms). `SPC td` toggles this auto-float for the session
  (`lua/config/diagnostic_float.lua`); `SPC ex` always shows it on demand
- Automatic linting is enabled on read and write when a supported linter exists
- Current machine support includes `shellcheck`, `yamllint`, `mypy`, fallback `pylint` or `flake8`, and `tflint`; ruff's diagnostics come from its LSP server, not from nvim-lint
- tflint is scoped to the edited file's module: the on-read/on-write linter is
  overridden (`lua/config/tflint.lua`, wired in `lua/plugins/lint.lua`) to run
  `tflint` with the file's directory as its working directory instead of
  nvim-lint's default `tflint --recursive`. The default scans the whole repo on
  every read/save, so editing several files in a large repo spawns many
  concurrent full-repo scans that saturate the CPU; the scoped form lints just
  the active module, and the parser keeps only the issues in the edited file.
  (An earlier form passed `--chdir=<abs dir> --filter=<file>`, which tflint
  silently matched against nothing, so it reported no issues at all.) For a
  wider run use `,cl` (see Terraform keybindings), which runs `tflint` from the
  project root
- terraform diagnostics are layered, and a bare invalid interpolation like
  `${foobar}` is intentionally not underlined live. terraform-ls's enhanced
  validation (on by default) resolves references only within `var.*` and
  `local.*` scope, so it flags `${var.nonexistent}` but not `${foobar}`; tflint
  does no reference resolution. The catch-all is `,cc` (`terraform validate`),
  which reports invalid/undeclared references. terraform-ls's
  `experimentalFeatures.validateOnSave` would surface these live but runs
  `terraform validate` per module (needs `terraform init`), so it is left off
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
  - Shell uses `shfmt`; Go uses `gofmt` + `goimports`; JavaScript/TypeScript use `prettierd` then `prettier`; JSON/Markdown/YAML use `prettier`; Lua uses `stylua`; Rust uses `rustfmt`; Terraform uses `terraform_fmt`; TOML uses `taplo`
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

- pylsp's `on_init` in `lua/plugins/lsp.lua` (via `strip_pylsp_capabilities` in `lua/config/lsp_util.lua`) strips `renameProvider`, `hoverProvider`, `definitionProvider`, `referencesProvider`, `documentSymbolProvider`, `workspaceSymbolProvider`, `completionProvider`, `signatureHelpProvider`, `declarationProvider`, `typeDefinitionProvider`, `implementationProvider`, and `documentHighlightProvider` from `client.server_capabilities` once, when the client initialises and before any `LspAttach` handler reads them. Only `codeActionProvider` is left, matching pylsp's actual job (rope refactors)
- `rename_with_preview` additionally prefers a client named `pyright` when multiple rename-capable clients remain, as belt-and-suspenders for non-Python stacks that might add another rename provider

If you add a new pylsp plugin that provides one of the stripped capabilities, remove the matching line from `strip_pylsp_capabilities` and restart the LSP.

### UI

- snacks.nvim `input` module replaces `vim.ui.input` (styled float, no lingering cmdline prompt)
- telescope-ui-select still owns `vim.ui.select`, so the scope picker and confirm-list use telescope

### Python refactoring stack

Python buffers attach three LSPs with a clear division of labor. Overlapping features are disabled so each server owns exactly one responsibility:

| Server | Role | Disabled features |
|---|---|---|
| pyright | types, hover, completion, go-to-def, rename | — |
| pylsp | rope refactoring code actions only | all features except `codeActionProvider` disabled (see `strip_pylsp_capabilities` in `lua/config/lsp_util.lua`) |
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

`SPC cm` (and the once-per-filetype warning) checks the same resolved `pylsp` path that LSP startup uses and warns if either piece is missing; `:checkhealth config` lists it too. The pipx fallback is looked up under `$PIPX_HOME` when that is set, else pipx's default `~/.local/share/pipx`. Ruff is already on PATH via flox.

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
  - `,hs` (`<localleader>hs`) also opens it in normal mode
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
- Python linting runs `mypy`, falling back to `pylint`, then `flake8`; ruff's diagnostics come from the ruff LSP server, so nvim-lint does not run it
- Python formatting prefers `ruff_organize_imports` plus `ruff_format`, then falls back to `black`, then `yapf`
- Python tests run through the same interpreter Neovim resolves for the current project
- Python debugging expects `ipdb` in that same interpreter and reports it through `SPC cm` and `:checkhealth config` if it is missing
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

- Jumping is powered by flash.nvim
- `s` triggers labeled jump mode
- `S` jumps by Treesitter nodes
- `SPC jj` jumps across visible text
- `SPC jt` jumps by Treesitter nodes
- `SPC jr` performs a remote jump
- flash also enhances the `f` / `F` / `t` / `T` char motions in normal, visual,
  and operator-pending mode (not insert): press the motion, the buffer dims
  while it waits for a target character, then it jumps to it -- searching across
  lines, not just the current one. `;` / `,` repeat forward / back, and `f` / `F`
  repeat clever-f style (same case next, opposite case previous). Because this
  is normal-mode only, an insert-mode chord like `fd` (Escape) is unaffected; a
  stray `f` that triggers this dim-and-wait usually means you were already in
  normal mode
- `gd` open definitions through Telescope
- `gi` open implementations through Telescope
- `gr` open references through Telescope
- `gy` open type definitions through Telescope
- `SPC ft` toggles the file tree
- `SPC pt` opens the project tree -- the same action as `SPC pe`, kept as a synonym
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
  - `,gM` document symbols
  - `,gi` implementation
  - `,gr` references
  - `,gs` workspace symbols
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
  - `,Tl` toggles inlay hints when the server supports them; pyright advertises none, so in Python buffers the toggle has nothing to show (basedpyright would supply them)
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
  - `,cg` views the saved file rendered by `glow` in a floating terminal (`q` closes)
- Terraform:
  - `,cc` runs `terraform validate`
  - `,cl` runs `tflint` from the project root (the on-read/on-write linter, by
    contrast, is scoped to the active file's module -- see Linting)
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
- `SPC tvt` toggles `list`; `SPC tl` is an alias
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

- On the first buffer for a supported filetype, Neovim warns once about missing tools for that workflow, half a second after the buffer opens
- There is no startup sweep: the full audit is `:checkhealth config` (`SPC cM`). The sweep used to run half a second after every launch and block for about 170 ms probing 28 features, which is what the audit costs on demand instead
- Tool checks treat inactive `mise` shims as missing so false positives do not hide broken commands
- Tool probes are cached for the session, keyed by `PATH` so a pyenv activation re-probes; `SPC cm` and `:checkhealth config` always probe afresh, so a tool installed mid-session shows up there first
- `SPC cm` checks dependencies for the current buffer, and reports success too
- `SPC cM` runs the full configured dependency audit as `:checkhealth config`
- The one feature table in `lua/config/deps.lua` also covers the servers `lsp.lua` configures (ansiblels, cssls, dockerls, taplo) and takes linter names from `lua/config/linters.lua`, so it cannot advertise a linter nvim-lint would not run

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

The per-filetype warnings and `:checkhealth config` come from `lua/config/deps.lua`. The binary names they show map to these Mason packages:

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

Not everything in the warnings is a Mason package: `glow` (Markdown terminal
view) comes from mise (`mise/config.toml`) or your system package manager.

Bulk install example for a typical frontend + backend workstation:

```
:MasonInstall html-lsp json-lsp css-lsp typescript-language-server prettierd clangd gopls goimports
```

### Trimming the dependency warnings

- Nothing warns on startup; `:checkhealth config` reports everything on demand
- `filetype_features` in `lua/config/deps.lua` maps filetype to the checks that run on first buffer open; remove entries for tools you never want to hear about

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
- The `file_watch` dependency check reports in `:checkhealth config`
  when no native backend is available, recommending `inotify-tools`
  (`inotify-tools port` on FreeBSD). Install it on your normal `PATH` (flox,
  system package manager) rather than via Mason: it is a system tool, not a
  language server.
- A file over 1.5 MB, or averaging over 1000 bytes a line, opens as the
  `bigfile` filetype (snacks.bigfile) with a warning saying so: no treesitter,
  LSP or folds, regex syntax only. A 3.2 MB Lua table opens in 0.6 s instead of
  2.2 s and redraws in 0.17 s instead of 1.7 s.

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
- Each spec is self-contained in what it loads: `-u NONE`, its own
  `package.path`, real repos and modules, plugins stubbed through
  `package.preload`; it prints `ok` / `FAIL` lines and calls `cquit 1` on
  failure so the runner sees a nonzero exit
- Run specs through `run.sh`, not with a bare `nvim --headless -u NONE -l
  <spec>`: Neovim's runtimepath loader wins over `package.path`, and
  `~/.config/nvim` is on the runtimepath even under `-u NONE`, so a direct run
  resolves `config.*` from the deployed copy rather than the checkout; `run.sh`
  prepends the checkout's `nvim/` to the runtimepath first (see
  [DEBUGGING_NVIM.md](./DEBUGGING_NVIM.md:1))
- The specs cover the pure helpers behind the keymaps (reflow, util,
  completion, code_mode, lsp_util), the git layer (gitdiff, the base and changed
  listings, the Oil column, the tree marks), the tool and dependency layer
  (tools, linters, deps, tflint, the Python environment, treesitter parsers) and
  the smaller guards (autocmds, big files, the diagnostic float, keymaps,
  which-key key names, the semantic-token guard, lsp_watch, projects); each
  file's header comment says what it covers and how the module used to fail, so
  `ls nvim/test` is the list
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
- Keep dependency reporting explicit (`:checkhealth config`, `SPC cm`) — surface
  missing tools rather than auto-installing them

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
- The Vim-era clip-in / clip-out shell clipboard fallback is gone from
  `lua/config/keymaps.lua`; revive it from git history if a host without a
  clipboard provider ever needs it (`SPC C` and `SPC Y` are live aliases, not
  part of it)
- The file tree's diff-base marks are ours, not neo-tree's: upstream accepts
  `:Neotree git_base=<ref>` and diffs `<base>..HEAD` for the same purpose, but
  at the tip of `v3.x` (`ebd6676`) every row fails to render with
  `git/init.lua:632: attempt to index local 'git_status' (a boolean value)`, and
  even working it cannot tell base-derived changes from uncommitted ones (it
  computes a `status_from_diff` flag and then ignores it). If upstream fixes
  both, the custom `git_status` component could be retired
- The Emacs-native long tail is unported: heavy Org integrations, Elfeed, the
  PDF workflow, the IETF/xkcd/speed-reading layers, and some secondary
  language/tooling layers

### Validation baseline

- `nvim --headless '+qa'`
- `nvim --headless '+Lazy! load all' '+qa'`
- `nvim/test/run.sh` passes
- `:checkhealth config` reports every dependency installed
