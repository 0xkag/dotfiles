# Refactoring Plan

A review of this config against its stated intent (README.md and the commit
history), carried out 2026-09-01 on Neovim 0.12.2. Five focused passes covered
startup and lazy-loading, the plugin stack, the LSP/completion/lint/format
layer, the git/tree/picker layer, and code quality plus documentation drift.
Every finding marked "confirmed" was reproduced against the code or at the
shell before it was written down.

Verdict: structurally sound and ahead of most setups (native `vim.lsp.config`,
disciplined lazy-loading, a real headless spec suite, rationale in the README),
but with a handful of silently broken features, several hot paths that spawn
processes synchronously on the main thread, and modules that have grown into
grab-bags. The defects in section 1 are fixed first; everything after that is
planned work.

Baseline measurements:

| Measurement                          | Result                                 |
|--------------------------------------|----------------------------------------|
| Startup, empty buffer                | 33 ms                                  |
| Startup, opening a `.py` file        | 85-95 ms                               |
| `nvim/test/run.sh`                   | 16 specs, 313 checks, pass in 0.56 s   |
| `Lazy! load all`, `:checkhealth`     | clean apart from lazy's luarocks note  |
| Startup, empty buffer (2026-09-02)   | 30-31 ms                               |
| `nvim/test/run.sh` (2026-09-02)      | 26 specs, 662 checks                   |

## Status and working method

Last updated 2026-09-02. This file is the single source of truth for the
refactoring; a fresh session needs nothing from earlier ones.

Done: section 1 (all eight defects), 2.1, 2.3, the 2.4 decisions, the safe
drops in 3, the `deps.lua` -> `:checkhealth config` item in 4, and the
python.lua and `configure_cmp` specs in 5. Deferred by decision: 2.2, 2.5 and
the NFS `directory` / `undodir` move, because NFS is out of scope for the
editor setup. Open: 2.6; the at-risk and consider lists in 3; the rest of 4;
the rest of 5; 6. Each open item ends with a "Payoff:" sentence, measured
where a measurement was cheap and estimated otherwise; structural payoffs
count as much as performance ones.

How each item was done, and should be:

- One item per commit, subject `nvim: Phrase`, body per
  `~/.dotfiles/_ai/memories/commit-message-format.md`. Tick or annotate the
  item here in the same commit, with the measurement and any corrected claim.
- Behaviour changes are spec-first: write or extend a spec under `nvim/test/`
  so it fails for the stated reason, then change the code. Run one spec with
  `nvim/test/run.sh <name>` and everything with `nvim/test/run.sh`. Specs are
  self-contained (`-u NONE`, real repos and modules, plugins stubbed through
  `package.preload`); `gitdiff_spec.lua` and `python_env_spec.lua` are the
  fullest examples.
- Verify live before committing when a plugin is involved: run the real config
  headless with `XDG_CONFIG_HOME=~/.dotfiles nvim --headless -c "luafile
  <probe.lua>"`, writing results to a file and ending with `qa!`. In a sandbox
  with a read-only state dir also point `XDG_STATE_HOME` and `XDG_CACHE_HOME`
  anywhere writable and `MISE_STATE_DIR` at the real mise state dir, or nvim
  logs to cwd and mise refuses its config.
- Work in `~/.dotfiles` on master, no branches or worktrees: `~/.config/nvim`
  is a symlink to `~/.dotfiles/nvim`, so a worktree's specs would test the
  deployed copy anyway (see `DEBUGGING_NVIM.md`).
- Measure before claiming a payoff. Several claims here turned out wrong on
  measurement (symlinked buffer names, `K` as a restatement) and are corrected
  in place rather than deleted, so the record stays honest.

## 1. Defects

Fixed one commit each; tick the box in the fixing commit.

- [x] **1. Scoped tflint produces zero diagnostics.** `lua/plugins/lint.lua`
  passes an absolute `--chdir` plus `--filter=<basename>`. tflint matches
  nothing in that combination: on a fixture that yields three warnings with
  `--chdir=<abs>` alone, adding `--filter=main.tf` yields none. Broken since the
  June scoping change (2df8956). Fix: run tflint with the file's directory as
  the process cwd (nvim-lint accepts a function-valued linter, called per run)
  and no `--filter`; override the parser to resolve each issue's cwd-relative
  filename against the linter cwd and keep only the buffer's issues (the
  upstream parser compares a nvim-cwd-relative name, which also fails for
  buffers outside cwd, and passes HCL's 1-based positions through unshifted).
  Spec: feed the parser tflint JSON.
- [x] **2. Visual-mode helpers act on the previous selection.**
  `util.visual_selection_text`, `util.squeeze_spaces_visual`, markdown's
  `visual_positions`, and shell's `shell_visual_range` read the `'<` / `'>`
  marks, which are stale inside an x-mode Lua mapping (the mapping fires while
  still in visual mode; the marks update only on leaving it). `reflow.lua`
  already solved this with `getpos("v")` / `getpos(".")` and FORMATTING_NOTES
  records the pitfall, but the fix never propagated. Reproduced headless:
  selecting `hello` returned `second line`; `,xb` raised an out-of-range error.
  Affected: visual `SPC %`, `g!`, `*` / `#`, markdown `,xb ,xi ,xc ,xq`, shell
  `,\`. Fix: one live-selection helper in `config.util`, used everywhere. Spec:
  drive a real x-map with `nvim_feedkeys` the way `reflow_spec` does; the
  existing `util_spec` visual test primes the marks by leaving visual mode, so
  it cannot catch this.
- [x] **3. Git paths are never unquoted.** `lua/config/gitdiff.lua` parses
  `git status --porcelain` and `git diff --name-status` without `-z`. Porcelain
  v1 C-quotes any path containing whitespace, and all three commands
  octal-escape non-ASCII under the default `core.quotePath`, so those files
  lose their marks in every view and `SPC gc` previews a quoted string. Fix:
  `-z` on all three commands and split on NUL (porcelain `-z` emits
  `XY new\0old\0` for renames; name-status `-z` emits `R100\0old\0new\0`).
  Spec: files with spaces and non-ASCII names, plus a rename, in a real repo.
- [x] **4. Dead `on_new_config` hooks.** `vim.lsp.config` has no such field.
  pylsp's `cmd` in `lua/plugins/lsp.lua` is therefore resolved once at startup
  with no root, so the README's "project venv pylsp wins over pipx" never
  happens. Fix: `cmd = function(dispatchers, config)` that resolves
  `python_env.pylsp_cmd(config.root_dir)` and calls `vim.lsp.rpc.start`;
  delete pyright's copy, whose `before_init` already does the work.
- [x] **5. pylsp capability strip runs in the wrong hook.** The runtime fires
  `LspAttach` before `config.on_attach`, so every LspAttach handler sees pylsp
  unstripped, and the strip reruns per buffer. Move it to `on_init`, which runs
  once per client after `server_capabilities` is set and before any attach.
  Extract the strip to `lsp_util` so it can be specced.
- [x] **6. Project tracker is fragile and busy.** `lua/config/projects.lua`
  asserts on a failed state-file write inside a BufEnter autocmd (a read-only
  or full state dir errors on every buffer switch); `read_projects` drops any
  directory that fails `fs_stat` and `list()` writes the pruned list back, so a
  project on an unmounted share is forgotten permanently; and every BufEnter
  re-reads, stats, and rewrites the file even when the head is unchanged. Fix:
  early return when the project is already at the head, `pcall` the write and
  notify once, write via temp file plus rename, keep missing directories and
  filter them only at display time. Spec: the read/write/dedupe logic.
- [x] **7. Deprecated calls.** `vim.lsp.stop_client` (warns now, removed in
  0.13) at two sites in `lua/plugins/lsp.lua`; `vim.highlight.on_yank` in
  `lua/config/autocmds.lua` (renamed `vim.hl.on_yank`). Fix: `client:stop()`
  per client; `vim.hl`.
- [x] **8. Smaller mismatches.** (a) Oil's status column does not refresh on
  `<C-l>`: its cache key is directory plus diff-base generation, so a refresh
  changes neither, contradicting the README's "correct on any redraw you ask
  for". Bump a local counter from the refresh mapping. (b) neo-tree's
  `hijack_netrw_behavior = "open_current"` fights Oil's
  `default_file_explorer`; set it to `"disabled"`. (c) The `,Tl` inlay-hint
  toggle is inert for Python because pyright has no `inlayHintProvider`;
  document it (basedpyright would supply one, see section 3).

## 2. Hot paths

Not startup: `lazy.setup` and the eager plugin set are cheap. The cost is the
config layer's process spawns on the main thread, which is what hurts on an
NFS home and in a monorepo.

### 2.1 Tool probing

Status: done 2026-09-01. `tools.status` is memoized per PATH with
`invalidate()` for the explicit audits (`:checkhealth config`, `<leader>cm`),
`notify_once` latches before checking, lint resolves the current filetype only
(`config/linters.lua`), and `grepprg` uses a plain executable check. Kept for
the record:

`lua/config/tools.lua` `status()` is uncached. `lua/config/env.lua` puts the
mise shims dir first on PATH, so any mise-managed tool resolves to a shim and
`status()` verifies it with a synchronous `mise which`. Measured here: about
16-18 ms per call, versus under 1 ms for a bare fork/exec, with mise's own
bin-path cache warm; the time is mise loading its config and resolving the
toolset, not the exec. Five of the tools checked at startup are shims (glow,
rust-analyzer, rustfmt, terraform, tflint).

Call sites that multiply it:

- `lua/config/deps.lua` `notify_once` only latches `notified[key]` when
  something is missing, so with everything installed the per-filetype check
  reruns on every buffer of that filetype (including `module_status("ipdb")`
  and `pylsp_status()`, each of which walks for `.python-version` again). Set
  the flag before the early return.
- `deps.lua` probes a missing binary twice (`executable()` then `status()`).
- `lua/plugins/lint.lua` `refresh_linters()` probes all seven linters on every
  `BufReadPost` and `BufWritePost` of any filetype.
- `lua/config/options.lua` calls `tools.available("rg")` before lazy loads,
  where `vim.fn.executable` would do.

Plan: memoize `tools.status` per binary, keyed by `vim.env.PATH` so pyenv
activation invalidates it; resolve only the current filetype's linters; use a
plain executable check for `grepprg`. Consider moving the `mise which`
verification into `:NvimDeps` only (it exists to catch inactive shims, which is
a diagnostic concern, not a per-buffer one).

### 2.2 Project tracking

Beyond defect 6: `M.track` runs on every BufEnter and calls `util.find_root`,
which is `vim.fs.root` with 14 markers (14 stats per directory level). Cache
the root in `vim.b[buf]`; consider tracking on `BufReadPost` / `BufNewFile`
only, keeping the MRU list in memory and writing on head change or
`VimLeavePre`.

Deferred 2026-09-02: NFS is out of scope for the editor setup. Payoff: on
local disk the whole BufEnter path costs well under 1 ms (`find_root` measured
at 0.028 ms for a file four levels below `.git`, plus one read of the state
file and one stat), so there is nothing to feel; it only matters on a
networked home, where each of the ~60 stats and the read is a round trip. The
write half is already done: since defect 6, `M.add` rewrites the file only
when the head project changes.

### 2.3 Synchronous git

Done, in the six commits from "Compare submodules by commit in the listings"
through "Preview SPC gc diffs in the background". The listings share one cache
per repo, run in the background behind `status_by_path`, compare submodules by
commit, and key their marks the way each view spells its paths; git.lua
resolves the default branch once per repo and verifies a ref before it becomes
the base. The map below is the situation as it was: every spawn in
`gitdiff.lua` went through `vim.fn.systemlist`.

| Site                         | Command                                   | Trigger                                              |
|------------------------------|-------------------------------------------|------------------------------------------------------|
| gitdiff `repo_toplevel`      | `rev-parse --show-toplevel`               | every `status_by_path`: picker open, Oil miss, `]g`, tree refresh |
| gitdiff `changed_files`      | `diff --name-status` + `ls-files` / `status --porcelain` | same, plus `SPC gC` empty-reason          |
| gitdiff `committed_files`    | `diff --name-status <base> HEAD`          | tree refresh / base change                           |
| git.lua base helpers         | symbolic-ref, rev-parse, merge-base       | each `SPC gm` / `SPC gM` press (up to ~8 spawns)     |
| git.lua `SPC gc` previewer   | `git diff`                                | **every selection move in the picker**               |
| util.lua `find_files`        | via `status_by_path`                      | blocks the picker opening on a whole-repo status     |
| neotree.lua `]g` / `[g`      | rev-parse + status (+ ls-files)           | per keypress, no cache                               |
| oil.lua column               | via `status_by_path`                      | per directory change; single global cache keyed by dir, so two Oil windows thrash |

Plan:

- [x] Compare submodules by recorded commit only (`--ignore-submodules=dirty`)
  in the three listing commands. Walking the 52 submodule worktrees under
  `_lib` was nearly the whole cost: 137 ms for a status and 106 ms for a diff
  in ~/.dotfiles, against 9 ms and 7 ms without it.
- [x] Cache the listings by repo toplevel plus a version counter rather than by
  directory, in `gitdiff` itself so Oil, the tree, the pickers and `]g` share
  one listing. The version bumps on a base change, on the events that bracket
  a git command the editor cannot see (`BufWritePost`, `FocusGained`,
  `ShellCmdPost`, `TermLeave`, `User GitSignsChanged`, `User OilActionsPost`,
  neo-tree's `GIT_STATUS_CHANGED`), and on Oil's `<C-l>`. A failed listing is
  cached too, and `repo_toplevel` is memoized per directory alongside.
- [x] `status_by_path(dir, { on_update })` lists in the background: it answers
  from the cache or with nothing, runs one listing however many views ask, and
  tells each callback to ask again once it lands. Oil redraws from its cached
  entries (`render_buffer_async` with `refetch = false`) unless the buffer
  holds unsaved edits; the file pickers call `picker:refresh()`. `]g` and
  `SPC gc` keep the blocking form, and the tree's base marks stay synchronous:
  `diff --name-status <base> HEAD` never touches the worktree and costs 2 ms.
- [x] `SPC gc` previews in the background, through `gitdiff.git_in_async`
  (`vim.system`) rather than telescope's `job_maker`, which needs plenary's
  Job and offers nothing over it here.
- [x] Cache `default_branch` per repo (eight `symbolic-ref` spawns over one
  `SPC gm` cycle became one); route `git()` through `repo_toplevel` so it
  works from `oil://` and neo-tree buffers.
- [x] Verify a ref before storing it as the base (`rev-parse --verify --quiet
  <ref>^{commit}`); `changed_files` honours `quiet`, so a redraw on a bad base
  is silent (landed with the background listing).
- [x] Key the marks the way the view spells its paths: `status_by_path` and the
  new `committed_by_path` respell every key under the caller's directory (a
  symlink above the repo or inside it), since `--show-toplevel` is physical
  while an Oil directory, a tree root or a `:cd` keeps the symlinked spelling
  (`~/.config/nvim` -> `~/.dotfiles/nvim`). The original claim about buffer
  names was wrong: Neovim resolves symlinks when it names a buffer, for
  `:edit` and `setqflist` filenames alike (verified on 0.12.2), so `SPC gC`'s
  prefix filter was never affected and needs no realpath.
- [x] `util.is_git_repo` asks `gitdiff.repo_toplevel` rather than looking for
  `cwd/.git`, so a nested project root inside a monorepo gets marks.
- [x] `committed_by_path` returns before asking git at the index base; the tree
  used to resolve the toplevel first and throw it away on every refresh.
- [x] Two "changed" sets exist by design and now share one name-status parser:
  tree rows use `committed_files` (base..HEAD) because neo-tree's own status
  already covers the worktree, everything else uses `changed_files`
  (base..worktree). Documented in the README rather than unified.
- [x] `core.untrackedCache` / `core.fsmonitor` recommended in the README for
  large repos.

### 2.4 Key timing and options

Status 2026-09-01: done for the `gr` defaults (deleted in keymaps.lua), the
insert-mode timeout (150 ms via InsertEnter / InsertLeave, restoring the
normal-mode value), `lazyredraw` (dropped), treesitter folding (the global
foldexpr is `config.treesitter.foldexpr`, which folds only buffers `attach`
marked; note
that Neovim 0.12's own ftplugins, `ftplugin/lua.lua` for one, set a
window-local `v:lua.vim.treesitter.foldexpr()` themselves, which the guard
cannot and need not override) and the lua_ls library
(runtime plus luv types). Struck: `wildoptions = { "tagfile" }` was set on
purpose in b1cb17c, not ported by accident. Left as decisions: the NFS
`directory` / `undodir` move (local disk loses undo history across reboots),
re-enabling snacks `bigfile` (explicitly disabled in ui.lua; it turns syntax
off above 1.5 MB), and the `[d` / `]d` / `K` / `Y` maps that restate defaults
(harmless, and they carry which-key descriptions).

Decisions (2026-09-02). NFS `directory` / `undodir`: deferred with 2.2, since
NFS is out of scope for the editor setup; on a networked home it would keep
swap and undo writes off the network, on local disk it changes nothing. snacks
`bigfile`: re-enabled. Measured on a 3.2 MB Lua table, opening went from 2.2 s
to 0.6 s and one jump-to-end redraw from 1.7 s to 0.17 s, because the buffer
gets the `bigfile` filetype before the treesitter hook or an LSP server sees
it; the cost is regex syntax only, above 1.5 MB or 1000 bytes a line, in
exactly those files. `Y`, `[d` and `]d`: dropped, since Neovim's own maps are
the same (`y$`; `vim.diagnostic.jump` with the same call) and `<leader>en` /
`<leader>ep` keep the leader spellings. `K`: kept. The original claim was
wrong; the config's hover adds a rounded border and its own close events, so
it never restated the default.

Kept for the record:

- `gr` (global and LSP buffer-local) sits on Neovim 0.11's `grn` / `grr` /
  `gri` / `gra` / `grt` prefix, so every `gr` waits the full `timeoutlen`
  (500 ms). Either `pcall(vim.keymap.del, "n", k)` for the defaults or accept
  the wait. `[d` / `]d`, `K`, and `Y` reimplement defaults.
- `timeoutlen = 500` also makes insert-mode `f` pause for the `fd` chord;
  neotree.lua already works around it locally. Consider ~200 or a timer.
- Drop `lazyredraw`; it is discouraged and fights `laststatus=3` / lualine.
- Move the treesitter `foldexpr` from global options to the treesitter
  FileType hook so it does not evaluate in buffers without a parser.
- lua_ls `library = nvim_get_runtime_file("", true)` indexes every plugin;
  restrict to `$VIMRUNTIME` or use lazydev.nvim.
- `wildoptions = { "tagfile" }` silently drops the default `pum`.
- On NFS: point `directory` / `undodir` at local disk; neo-tree's
  `use_libuv_file_watcher` does nothing useful there.
- snacks `bigfile` is disabled while treesitter starts on every buffer with a
  parser and folding is global; a huge generated file will hang. Re-enable.

### 2.5 Python activation

`lua/config/python.lua` spawns `pyenv prefix <ver>` synchronously on
`BufReadPre *.py` (cached per version, but pyenv is a slow bash script and this
lands inside startup for `nvim foo.py`). `version_file_for_dir` stops only at
`$HOME`, so files outside HOME walk to `/`. Plan: resolve
`$PYENV_ROOT/versions/<ver>` with `fs_stat` and spawn only as a fallback; add
`vim.fs.root(start, ".git")` as a second stop; cache per directory.

Deferred 2026-09-02: minor. Payoff: `pyenv prefix` measured at 11-13 ms, paid
once per version per session on the first `.py` buffer, where a stat of
`$PYENV_ROOT/versions/<ver>` answers in microseconds. The git-root stop only
matters for Python files outside `$HOME`.

### 2.6 Lazy triggers

Mostly right. Tighten: telescope (`event = "VeryLazy"` plus `cmd` / `keys`;
the event wins, dragging plenary and ui-select in at UIEnter -- a tiny
`vim.ui.select` shim that loads telescope on demand is cheaper), orgmode (`ft`
plus `cmd` plus `keys` instead of VeryLazy), cyberdream (`lazy = true`; lazy's
colorscheme handler loads it on demand, and `colors/cyberpunk.lua` is what
actually gets applied), flash and hydra (`keys`). snacks stays eager
(`lazy = false`, 0.57 ms): bigfile's filetype pattern has to be registered
before the first buffer is read. Ungrouped autocmds: deps, python,
treesitter, kulala, terminal, lsp, git, neotree.

Payoff (measured 2026-09-02, dependencies included): loading telescope costs
8.8 ms, hydra 8.4 ms, orgmode 3.5 ms, flash 0.7 ms; lualine (5.2 ms) is the
statusline and stays. All are VeryLazy, so none delays the first frame; together
they are ~21 ms of work right after the UI appears, which the tighter triggers
move to first use. cyberdream loads at startup today (2.1 ms), so that item is
worth at most that. Grouping the autocmds has no runtime payoff; it is what
makes `:autocmd` readable and a re-source clean.

## 3. Plugin stack

Safe drops:

- Done 2026-09-01: `mason-lspconfig.nvim` dropped. With `automatic_enable =
  false` it only registered `:LspInstall` / `:LspUninstall` and scheduled a
  registry refresh, and listing it and mason as dependencies of nvim-lspconfig
  defeated mason's own `cmd` laziness. `env.lua` already puts `mason/bin` on
  PATH without the plugin.
- Decided 2026-09-01: keep `mini.comment` plus `nvim-ts-context-commentstring`.
  0.12's built-in `gc` / `gcc` is injection-aware and uses the same keys, but
  checked under `nvim --clean` it puts the bare leader on blank lines inside a
  range (`--`), where mini.comment's `ignore_blank_line = true` leaves them
  empty. That behaviour is wanted, so the two plugins stay.
- Done 2026-09-01: the nvim-treesitter master-branch fallback in
  `lua/plugins/treesitter.lua` (unreachable, the lock pins `main`), the
  `parser_by_filetype` table in `lua/config/treesitter.lua` (unreachable,
  `get_lang` never returns nil) and `register("terraform", "tf")` (no `tf`
  filetype exists) are gone. `missing_for_filetype` now reports only parsers
  this config lists, so a tftpl buffer no longer asks for a `tftpl` parser.

At risk:

- `hydra.nvim` backs only `symbol-highlight.lua`; the fork has had no commits
  since 2025-05. Replacement: which-key `show({ loop = true })` or a
  hand-rolled buffer-local layer with a hint float (~70 lines). Payoff: the
  one dependency with no maintainer goes, along with its 8.4 ms VeryLazy load
  (measured 2026-09-02); the replacement is code you own. Risk reduction, not
  speed.
- `toggleterm.nvim` is dormant (last commit 2024-12) but works;
  `Snacks.terminal` could replace it in ~40 lines across `terminal.lua`,
  `code_mode/shared.lua`,
  and `code_mode/markdown.lua`. Payoff: one fewer dormant dependency, no
  user-visible change. Low; do it when toggleterm breaks.

Consider:

- `nvim-web-devicons` -> `mini.icons` with `style = "ascii"` and
  `mock_nvim_web_devicons()`: fits the PuTTY plain profile the README
  describes, and today Oil's icon column and lualine still emit Nerd glyphs.
  Payoff: those glyphs stop rendering as tofu in PuTTY, which is what the
  plain profile promises; the icon column becomes readable in every Oil
  buffer. Startup gain is negligible (devicons loads in 0.19 ms).
- `basedpyright` in place of `pyright`: same engine, adds inlay hints and
  semantic tokens (makes `,Tl` real); set `typeCheckingMode = "standard"` for
  parity. `ty` is lighter but still incomplete as a checker in 2026. Payoff:
  inlay hints and semantic highlighting in Python, and a toggle that today
  does nothing starts working; same engine, so diagnostics do not change.
- mypy via nvim-lint duplicates pyright's type diagnostics and spawns per read
  and per write (1-3 s); consider `dmypy` or `BufWritePost` only. Payoff:
  1-3 s of CPU per Python read and write, in the background but competing
  with the LSP servers, becomes sub-second re-checks with `dmypy` or half as
  many spawns with write-only; the duplicated type diagnostics go either way.
- shellcheck / shfmt are configured for zsh, which neither tool parses.
  Payoff: one wasted spawn per zsh read and write, and no more diagnostics
  about zsh syntax that shellcheck cannot parse; correctness of the list, not
  speed.
- `snacks.bufdelete` could replace `mini.bufremove`; `snacks.rename` would
  give LSP file-rename on Oil moves. Payoff: `bufdelete` saves nothing
  (mini.bufremove is a module of the already-loaded mini.nvim); `rename` is
  the value, since moving a file in Oil today leaves every import of it
  broken.

Keep, and do not migrate:

- lazy.nvim over `vim.pack`: `vim.pack` has no `keys` / `cmd` / `ft` /
  `event` / `dependencies` / `build`, which every spec here uses.
- telescope over snacks.picker / fzf-lua: deep custom integration
  (entry makers, git marks, project picker); PICKER_NOTES.md already
  concluded there is no gap.
- nvim-cmp over blink.cmp or native `vim.lsp.completion`: the quiet-mode
  state machine in `lua/config/completion.lua` relies on cmp's `debounce` and
  re-`setup` semantics; blink has no user debounce, and native completion
  drops luasnip / path / buffer sources. Revisit only when nvim-cmp breaks.
- inc-rename, multicursor, aerial, persistence (complementary to
  projects.lua, not redundant), snacks `input`, plenary / nui (required).

## 4. Structure

- `lua/plugins/lsp.lua` is one 885-line `config` closure: client helpers and
  commands, the server table, diagnostics and global keymaps, multicursor and
  LSP rename, a ~70-map LspAttach block with the signature-template feature,
  the watch guard and enable loop, `PyrightWorkspaceMode`. Split into
  `config/lsp_servers.lua` (data; testable), `config/lsp_keymaps.lua`,
  `config/lsp_rename.lua`, `config/lsp_signature.lua`. Replace the per-server
  capabilities / on_init loop with `vim.lsp.config("*", ...)`. Dead:
  `ensure_clients`' `action` param, the `codelens` / `inlay_hint` existence
  guards, `clients_for`. Payoff: the server table becomes data a spec can
  load without booting the 885-line closure, and a change to one concern
  (rename, signature) touches one file. No runtime change; the dead code is a
  few dozen lines.
- `lua/config/util.lua` holds seven unrelated groups: root markers, telescope
  pickers and the mark entry maker, listchars, visual search/substitute,
  quickfix grep, GNU Global, whitespace squeeze. Split into `root.lua`,
  `pickers.lua` (or fold into gitdiff, which would also remove the lazy
  require cycle gitdiff <-> util), `grep.lua`, `gtags.lua`, `editing.lua`;
  listchars belong with options. Payoff: each group becomes requireable on
  its own (grep no longer pulls telescope's entry maker into scope), and the
  require cycle goes. No runtime change.
- Done 2026-09-02: `lua/config/deps.lua` is one sorted feature table read two
  ways, the once-per-filetype warning (kept; `<leader>cm` forces it for the
  current buffer) and `:checkhealth config` via `lua/config/health.lua`. The
  startup sweep, `:NvimDeps` and the three hand-kept lists are gone; the
  servers no list checked (ansiblels, cssls, dockerls, taplo) have features,
  and the linter features take their candidates from `config.linters`, so
  ruff is no longer advertised as a linter. Payoff (measured): the sweep ran
  500 ms after VimEnter and blocked for 172 ms with the tool cache cold as it
  is on every launch (28 features; the mise-managed tools cost ~17 ms each).
  That freeze is gone; the same probe now runs on demand.
- Duplicated helpers to collapse: PATH prepend (`env.lua` vs `python.lua`);
  "buffer dir or cwd" (shared, python, git, terraform); `executable()`
  wrappers (deps, lint) and raw `vim.fn.executable` calls that bypass the
  mise-aware `tools` (autocmds, markdown, lsp_watch, python); a buffer-local
  `map` closure written twelve times (code_mode/init x8, lsp, python, kulala,
  terminal) -> `shared.buf_map(buf)`; terminal-mode `<Esc>` / `<C-hjkl>` maps
  in both `keymaps.lua` and `terminal.lua`, with `<C-\>` bound twice;
  which-key `desc` rows that restate keymap descs (the spec label wins, so the
  keymap desc is dead and the wording already differs); `vim.uv or vim.loop`
  in eleven files (floor is 0.12). Payoff: one place to fix a helper, and one
  real bug class today: the raw `vim.fn.executable` calls miss mise shims, so
  python.lua and lsp_watch can see a tool the rest of the config does not.
  Otherwise readability; no runtime change.
  Done 2026-09-02 for the executable checks: autocmds, markdown, lsp_watch
  and python ask `tools.available`, deps lost its `executable()` wrapper,
  `tools` passes the basename to `mise which` so a shim named by its path
  resolves, and tools_spec fails on any new raw call (options.lua keeps its
  plain `grepprg` check on purpose, before lazy loads). The live case was
  glow: mise-managed here, so a raw check reported it present while the shim
  was inactive and the terminal failed. The rest of this item is open.
- `code_mode`: actions live per language but keymaps come from four places
  (code_mode/init.lua, plugins/python.lua `,t*`, kulala.lua, lsp.lua). Give
  each module one shape, `{ filetypes, actions, keymaps(buf) }`, and have
  init.lua iterate. The merge loop flattens namespaces; terraform exports
  unprefixed names. Leftovers: a fish branch with no fish pattern,
  `shared.shellescape` alias, `markdown_wrap_pair` building two closures to
  call one. Payoff: adding a language becomes one module in one shape, and
  the flattened namespace stops an unprefixed export shadowing another
  language's. No runtime change.
- Keymap hygiene: `,gA` / `,gs` / `,gS` all run `lsp_dynamic_workspace_symbols`
  yet promise "types" / "all"; `,gd` == `,gt`; `,gR` == `,gr`; `<leader>tl`
  == `<leader>tvt` (undocumented). kulala's `,r ,a ,i` sit under the global
  refactor / action / insert groups; reuse `register_git_editor_labels`.
  Missing `desc` on several keymaps.lua entries. Payoff: which-key and the
  README stop promising keys that do something else; each of `,gA`, `,gd`
  and `,gR` is a user-facing lie today.
  Done 2026-09-02: `,gA`, `,gR`, `,gS` and `,gt` are gone and the README
  keeps `,gs`, `,gr` and `,gd` (a real type search would be
  `lsp_dynamic_workspace_symbols` with `symbols = { class, struct,
  interface, enum }`, but telescope warns on every keystroke whose results
  hold no such kind, so it is not worth the noise); `<leader>tl` stays as a
  wanted alias of `SPC tvt` and the README now says so (it was removed on
  2026-09-02 and put back the next day); kulala registers buffer-local labels
  for `,r ,a ,i` the way the git editors do; every keymaps.lua map has a
  desc; keymaps_spec holds each of these.
- `options.lua`: clipboard state and `_G.NvimClipMode` belong in
  `config/clipboard.lua`; three noexpandtab autocmd blocks -> one pattern;
  several options restate defaults; `colorcolumn=80` / `textwidth=78` vs
  gitcommit 75/76. Payoff: readability, plus the commit-message width and the
  column guide agreeing in gitcommit buffers. Small.
- Coupling: the neo-tree components are installed by mutating
  `neo-tree.sources.<x>.components` before setup rather than via the documented
  per-source `components` key, and `]g` reimplements upstream's command using
  internal `utils` / `renderer` / `navigate` functions. Oil's column uses
  undocumented but stable `columns.register`. Telescope wraps the public
  `gen_from_file`. Moderate risk on neo-tree upgrades. Payoff: insurance. A
  neo-tree release that renames `utils` / `renderer` / `navigate` breaks `]g`
  and the plain profile silently today; on the documented API it keeps
  working or fails loudly. No immediate change.

## 5. Tests

Strong where they exist, all real-repo and real-module. Gaps:

- No spec for conform's Python formatter function,
  `lsp_watch.install_git_head_refresh` / `cleanup`, and `prepare_for_expand` /
  `rollback_expand`. Closed since the analysis: the tflint parser,
  `config/treesitter.lua`, `projects.lua`, `config/tools.lua`,
  `config/linters.lua`, `config/deps.lua`, the `gr` keymaps and the big-file
  guard each have a spec (2026-09-01/02); `config/python.lua` has
  `python_env_spec` (2026-09-02), run against a fake pyenv, fake prefixes and a
  pipx home pointed at scratch through the newly honoured `$PIPX_HOME`;
  `configure_cmp` is covered in `completion_spec` through a fake cmp table
  (2026-09-02), and the first run caught a live defect: `manual and false or
  {...}` yields the table for every mode, so manual completion had been firing
  on every keystroke since it was written. Payoff: defects 1, 4 and 6 all
  lived in modules without a spec, and the 2.3 rewrite could change every
  listing call because the specs ran instead of a manual check.
- Untested gitdiff cases: `default_branch` via `origin/HEAD` or `main`,
  detached HEAD. Closed: quoted / space / non-ASCII paths and rename records
  in both parsers, the listing cache and its invalidation, the background
  listing, submodules, and symlinked directories (gitdiff_spec, 2026-09-02).
  Payoff: `origin/HEAD` and detached HEAD are the two paths `SPC gm` takes
  on a real clone that no spec drives; a regression there shows up only in
  use.
- `neotree_symbols_spec` regex-scans the source; `neotree_base_marks_spec`
  stubs seven neo-tree modules and reimplements `is_subpath` /
  `sort_by_tree_display`, so plugin API drift passes green. Add one
  integration spec per plugin with the real plugin on `rtp`. Payoff: a
  neo-tree or Oil API change turns into a red run instead of a broken column
  found in use; cost is the plugin on `rtp` and roughly a second per spec.
- The specs are pinned to the checkout only via `run.sh`; the "Run:" header in
  twelve specs and the README's direct `-u NONE -l` invocation resolve
  `config.*` from `~/.config/nvim`. Payoff: a spec run by its header from a
  worktree stops testing the deployed copy and reporting green for the wrong
  code.
- Shared helpers: `check()` is defined twenty-six times, an inline `git()`
  five times -> `test/helpers.lua`. `diagnostic_float_spec` / `reflow_spec`
  leave `vim.notify` unstubbed. `code_mode_spec` says default `sw=2` (it is 8).
  Payoff: one `check()` to improve (a failure diff, say) instead of
  twenty-six, and quieter runs; no behaviour change.

## 6. Documentation

- README.md (848 lines) is a user manual, a design log, and a backlog in one
  file, with ten Markdown files in the config root. Proposed layout:
  `README.md` (purpose, install, tests, index; ~150 lines), `docs/keys.md`
  (core keys, groups, git, language localleader, HTTP),
  `docs/design/{formatting,pickers,remote-runbooks,debugging-nvim,
  debugging-python,freebsd}.md`, `docs/upstream/{bugs,neovim-semantic-tokens,
  terraform-ls-delta}.md`, `docs/backlog.md`. Payoff: a key is found in
  `docs/keys.md` without scrolling past design history, and each design note
  gets a stable link; estimate ~150 lines of README from 848.
- Add `nvim.log` to `.gitignore`: nvim falls back to logging in cwd when the
  state dir is not writable, which is where the stray zero-byte files came
  from. Payoff: a clean `git status` after any run with an unwritable state
  dir; one line.

README drift found (verify each when reorganising). Payoff of fixing the
open rows: each one is a statement the README makes today that sends a
reader to a key or tool that does something else.

| README claim                                          | Code                                                        |
|-------------------------------------------------------|-------------------------------------------------------------|
| `SPC C` / `SPC Y` "remain disabled reference comments" | removed from keymaps.lua; comment says revive from history  |
| `SPC m h s` opens signature help                      | `,hs`; `SPC m` is the multicursor group                     |
| `SPC r` is "tests"                                    | which-key group is "run"                                    |
| ruff is a linter                                      | nvim-lint excludes ruff; diagnostics come from the LSP only |
| JSON / Markdown / YAML use `prettierd` then `prettier` | prettier only                                              |
| ~~`,gA` searches project types~~                      | the key and the claim are gone                              |
| ~~css-lsp in the dependency table~~                   | `css_lsp` feature added with the checkhealth move           |
| five specs listed                                     | twenty-six in `test/`                                       |
| direct `-u NONE -l` is self-contained                 | resolves the deployed copy; only `run.sh` pins the checkout |
| "Migration Notes" title                               | the tracker was retired                                     |
| ~~Oil is the default explorer~~                       | true since defect 8b was fixed                              |
| FORMATTING_NOTES: `,=` maps live in keymaps.lua       | they are in lsp.lua                                         |
| ~~tflint is scoped with `--filter`~~                  | README now describes the fix (defect 1)                     |
| ~~Oil marks are right on any redraw you ask for~~     | true since defect 8a was fixed                              |
| ~~project venv pylsp wins over pipx~~                 | true since defect 4 was fixed                               |
