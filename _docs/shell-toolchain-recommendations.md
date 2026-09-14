# Shell Toolchain Productivity Review & Recommendations

## Context

This is a deep analysis of the core shell tooling in this dotfiles repo (`tmux`,
`nvim`, `_shell`, `fzf`, `zsh`, `git`, `ssh`) with concrete productivity
improvements. It is a **recommendations backlog**, not applied changes. It is biased
toward *augmenting* the existing, deliberate setup (OMZ + pinned submodules, modular
POSIX shell init, Telescope-based nvim, documented Spacemacs→nvim migration), with a
few *targeted swaps* called out where the upgrade is decisive. Items that conflict
with the owner's demonstrated stability preference are flagged ⚠️.

The config is expert-level and internally consistent. The opportunities below are
mostly **config-only layering** and filling genuine gaps — not rewrites.

**How to use this doc (for future agents / future me):** each item is
self-contained — it names the exact file to edit, gives a ready-to-paste snippet,
states install mechanism, and lists per-item verification at the bottom. Update the
`**Status:**` line on an item as work progresses (⬜ not started / 🚧 in progress /
✅ done / ❌ rejected), and add a dated note under the appendix when the landscape
shifts. Commit changes to this file alongside the config changes they track.

### Assessment timeline
- **Original assessment: 2026-06-01** (repo at commit `e83e005`).
- **Reassessment: 2026-07-29** (repo at commit `d185bcd`) — see the Appendix.
- **Reassessment: 2026-09-14** (repo at commit `71a9ad6`) — see the Appendix. All
  ground-truth below was re-verified on 2026-09-14 on the AL2 host itself. Items
  #16–#18 added.

### Ground-truth (verified 2026-09-14)
- **Installed (provider in parens):** `ripgrep 15.1.0` (flox), `fzf 0.71.0` (mise
  shim; a stale `0.67.0` download from `fzf/install` still sits in `_lib/fzf/bin/`
  at the *end* of PATH — see #17), `mise 2026.4.5`, `flox 1.9.0` (rpm),
  `nvim 0.12.2` (flox), `pygmentize` (pyenv), `tmux` (homedir build in
  `~/.root/bin`, source in `_lib/_opt/tmux`), `tree 1.6` (rpm), `git 2.47.3`,
  `OpenSSH 7.4p1`, `zsh 5.8.1`, `bash 4.2`. Host is Amazon Linux 2.
- **Missing:** `fd`, `bat`, `delta`, `difftastic`, `eza`/`lsd`, `zoxide`, `atuin`,
  `direnv`, `starship`, `sesh`.
- **Versions vs. recommended keys:** git 2.47 supports every key in #3/#6
  (`zdiff3` ≥2.35, `rebase.updateRefs` ≥2.38); OpenSSH 7.4 supports every key in
  #1/#5 (`%C` ≥6.7, `ControlPersist` ≥5.6, `AddKeysToAgent` ≥7.2, `Include` ≥7.3).
- **SSH:** no ControlMaster multiplexing (`ssh/config` is 12 lines: EscapeChar + ForwardAgent/X11 off) despite a socks-`ProxyCommand` work setup — highest-latency win.
- **fzf:** `FZF_DEFAULT_COMMAND` unset → fzf uses its slow built-in walker and ignores `.gitignore`, even though `rg` is installed. Shell integration is `source <(fzf --zsh)` / `eval "$(fzf --bash)"` (`~/.fzf.zsh`, `~/.fzf.bash`), so the key-binding scripts always match whichever binary wins PATH.
- **mise:** deliberately **shim-based, not `eval`-activated** — `mise activate` is commented out (`_shell/shellinteractive:148-158`) in favor of a custom `MISE_DISABLE_TOOLS` exclusion system with per-prompt cached sync (`_mise_disable_sync`, `mise-refresh`, `mise-all`, `_shell/shellinteractive:160-202`; `_shell/shellenv:165-174`). This is intentional and sophisticated — see item #12. Reworked into a data-driven skip engine on 2026-07-01 (commit `b1e77d8`).
- **Binary hierarchy (per host):** system packages → flox (only on hosts that use it; this one does) → mise → homedir builds (`~/.local`, `~/.root`). On non-flox hosts the middle tier is simply absent. `mise/check-tools` implements this: it probes PATH with every `*/shims` dir skipped ("system rpm, then flox, then a homedir build — whatever comes first wins", `check-tools:131-148`) and disables the mise copy per-tool policy. On this host flox supplies rg, nvim, glab, yq, mc, glow, pandoc, shellcheck, node, go. `flox activate` is deliberately off (`_shell/shellinteractive:143-147`); the env is injected by direct PATH/MANPATH/PKG_CONFIG_PATH entries in `_shell/shellenv`. Manifest lives in the site repo (`_sites/work/flox/manifest.toml`); an AL2 package list was committed to `_reqs/flox-al2.txt` on 2026-09-13 (`aad2f29`).
- **nvim:** nvim-cmp + Telescope with **no** telescope-fzf-native (absent) and **no** nvim-dap (absent) — both match the documented `PICKER_NOTES.md` / `DEBUGGING_PYTHON.md` deferrals. `snacks.nvim` is now installed but only for the big-file guard. `nvim/TODO_REFACTORING.md` (2026-09-13) records explicit decisions: Telescope over snacks.picker/fzf-lua, nvim-cmp over blink.cmp ("revisit only when nvim-cmp breaks") — see #15.
- **EDITOR is now `nvim`** (`_shell/shellinteractive:65`; switched 2026-06-30, commit `11f1e0b`) — raises the payoff of the nvim-side items.
- **Shell startup (new, measured 2026-09-14 on the host):** `zsh -i -c exit` ≈ 0.53 s, bash ≈ 0.37 s. Of the zsh total, ~220 ms is three **no-op** `path-insert` calls (a Python script, run via the pyenv shim) from `_sites/work/_shell/shellenv` with empty lists; ~36 ms `kubectl completion zsh`; ~53 ms pyenv init + virtualenv-init; ~33 ms six `wd add!` calls; OMZ itself ≈ 30 ms and compinit ≈ 9 ms. See #16.

### Repo conventions a fresh agent needs
- **Install model:** symlink-based via `_bin/dotfiles-install` (Python); external tools pinned as **git submodules under `_lib/`**. Binaries follow a **per-host hierarchy arbitrated by `mise/check-tools`**: system packages → flox (hosts that use it) → mise → homedir builds (`~/.local`, `~/.root`). `mise/config.toml` is the **portable** tool list every host shares; the flox manifest (`_sites/work/flox/manifest.toml`) is per-site. For a *new* CLI tool (fd, bat, delta, zoxide…): add it to `mise/config.toml` so every host gets it, and on flox hosts optionally to the flox manifest too — `check-tools` then skips the mise copy wherever a higher tier already provides it. Run `mise-refresh` after installing. Add a `policy[...]` row in `check-tools` only if the default `newer` is wrong.
- **Site overrides:** identity/host-specific config lives in `_sites/current/` (a symlink, currently → `work`). Machine-specific and identity-specific settings belong there, not in the shared files.
- **Shell init chain:** `~/.zshrc`/`~/.bashrc` → `_shell/shellrc` → `_shell/shellenv` (env/PATH) + `_shell/shellinteractive` (aliases, fzf, editors). zsh specifics in `zsh/zshrc` (OMZ). Keep bash+zsh compatibility in `_shell/*`.
- **Commit style:** `topic: Phrase` subject, `--` body bullets, 75-col wrap, ASCII-only, `Co-Authored-By` last (see `_ai/memories/commit-message-format.md`).

---

## Priority Ranking (impact ÷ effort)

| # | Change | Area | Impact | Effort | Swap? | Status |
|---|--------|------|--------|--------|-------|--------|
| 1 | SSH ControlMaster multiplexing | ssh | ★★★★★ | tiny | augment | ⬜ |
| 2 | `FZF_DEFAULT_COMMAND`/`CTRL_T` via rg+fd, bat previews | fzf | ★★★★☆ | small | augment | ⬜ |
| 3 | git `delta` pager (or difftastic) | git | ★★★★☆ | small | augment | ⬜ |
| 4 | `fzf-tab` for zsh completion | zsh | ★★★★☆ | small | augment | ⬜ |
| 5 | SSH keepalive + per-host hygiene | ssh | ★★★☆☆ | tiny | augment | ⬜ |
| 6 | git: worktree aliases, rerere, histogram diff, branch sort | git | ★★★☆☆ | small | augment | ⬜ |
| 7 | `zoxide` alongside `wd` | shell | ★★★☆☆ | small | swap-ish | ⬜ |
| 8 | `fd` + `bat` installed as fzf/preview backends | shell | ★★★☆☆ | small | augment | ⬜ |
| 9 | tmux: TPM session picker + fzf/sesh, copy hardening | tmux | ★★★☆☆ | small | augment | ⬜ |
| 10 | nvim: telescope-fzf-native | nvim | ★★★☆☆ | tiny | augment | ⬜ |
| 11 | nvim: Python DAP (deferred Milestone 5) | nvim | ★★★☆☆ | medium | augment | ⬜ |
| 12 | per-project env: mise `[env]` (installed) vs direnv | shell | ★★☆☆☆ | small | augment | ⬜ |
| 13 | `atuin` shared/encrypted history | shell | ★★★☆☆ | medium | ⚠️ swap | ⬜ |
| 14 | git signing (SSH-key signing) | git | ★★☆☆☆ | tiny | augment | ⬜ |
| 15 | nvim: blink.cmp, trouble.nvim, fidget | nvim | ★★☆☆☆ | medium | ⚠️ swap | ❌ blink · ⬜ trouble/fidget |
| 16 | shell startup: skip empty `path-insert`, cache kubectl completion | shell | ★★★☆☆ | tiny | augment | ⬜ |
| 17 | fzf provider cleanup: stale `_lib/fzf/bin/fzf`, install step, pin | fzf | ★★☆☆☆ | tiny | augment | ⬜ |
| 18 | mise/flox hygiene: `mise prune`, reconcile flox lists | shell | ★☆☆☆☆ | tiny | augment | ⬜ |

Status legend: ⬜ not started · 🚧 in progress · ✅ done · ❌ rejected

---

## 1. SSH — ControlMaster multiplexing (highest single win)

**Status:** ⬜ not started

**Why:** Every `ssh`/`git`/`scp`/`rsync` to a host currently reopens a full TCP +
auth handshake. Through the work `ProxyCommand=connect-wrapper -S socks…` (set in
`_sites/work/git/gitconfig` `core.sshCommand`) this is especially slow. Multiplexing
reuses one master socket → subsequent connections are near-instant. Single biggest
latency improvement available.

**File:** `ssh/config` (extend the existing `Host *` block, lines 9–11).

```sshconfig
Host *
    ForwardAgent=no
    ForwardX11=no
    ControlMaster auto
    ControlPath ~/.ssh/cm/%C            # %C = hash of host+port+user; no leakage
    ControlPersist 10m                   # keep master alive 10m after last session
    ServerAliveInterval 30
    ServerAliveCountMax 3
    TCPKeepAlive yes
```

**One-time setup needed:** `~/.ssh/cm/` must exist — `mkdir -p ~/.ssh/cm && chmod 700
~/.ssh/cm`. Add this to `_bin/dotfiles-install` so it's provisioned automatically.
`EscapeChar ~` (line 3) already supports the nested-tmux workflow; multiplexed
sessions still honor `~.` to drop a single channel.

**Caveat:** masters can wedge if a connection dies badly — `ssh -O exit host` clears
one. Consider a tiny `_bin/ssh-cm-reset` helper (`rm -f ~/.ssh/cm/*` or loop
`ssh -O exit`).

## 5. SSH — remaining hygiene

**Status:** ⬜ not started

- Add `AddKeysToAgent yes` and (macOS work laptop only) `UseKeychain yes` under `Host *`.
- `Include ~/.dotfiles/_sites/current/ssh/config` is already the first line — good.
  Keep host-specific `ProxyJump`/bastion entries in that site file, not the shared one.

---

## 2 & 8. fzf — wire up ripgrep/fd/bat (rg already installed)

**Status:** ⬜ not started

**Why:** `FZF_DEFAULT_COMMAND` is unset, so `CTRL-T` and bare `fzf` use fzf's slow
internal file walk and ignore `.gitignore`. `rg` is already on the box. `fd` and
`bat` are missing but are the standard fast backends and dramatically improve
previews. Current previews use `pygmentize` (slower, Python startup) + `tree`.

**File:** `_shell/shellinteractive` (the existing `FZF_*` block, ~lines 164–192).

```sh
# Prefer fd, fall back to rg, then find. Respects .gitignore, includes hidden.
if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
elif command -v rg >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# bat preview if available, else keep pygmentize->cat->tree chain
if command -v bat >/dev/null 2>&1; then
    export FZF_CTRL_T_OPTS="--preview '(bat --style=numbers --color=always {} || tree -C {}) 2>/dev/null | head -200'"
fi
```

Keep the existing `ctrl-o`/`ctrl-y` binds and `FZF_CTRL_R_OPTS` — they're good.
**Install mechanism (updated 2026-09-14):** add `fd` and `bat` to `mise/config.toml`
(the portable list); on flox hosts optionally add them to
`_sites/work/flox/manifest.toml` as well (`fd.pkg-path = "fd"`, `bat.pkg-path =
"bat"`) and `check-tools` will skip the mise copy. Then `mise-refresh`. Note
Debian's packages expose `fdfind`/`batcat`; if using the distro-package route,
alias them in `_shell/shellenv`.

---

## 4. zsh — fzf-tab (best per-keystroke upgrade)

**Status:** ⬜ not started

**Why:** Replaces zsh's default completion menu with an fzf-driven, previewable one —
`cd <Tab>` shows a directory preview, `git checkout <Tab>` fuzzy-filters branches,
`kill <Tab>` previews processes. Pure augmentation; doesn't change keybindings or OMZ.
Pairs with `gitfast` + `wd` already loaded (`zsh/zshrc:74+`).

**Install (matches submodule model):** add `Aloxaf/fzf-tab` under `_lib/`, then in
`zsh/zshrc` source it **after** compinit (OMZ runs it) but **before** widget-wrapping
plugins:

```zsh
source ~/.dotfiles/_lib/fzf-tab/fzf-tab.plugin.zsh
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'tree -C $realpath 2>/dev/null | head -200'
zstyle ':completion:*' menu no              # fzf-tab needs default menu off
```

⚠️ Ordering sensitivity with the `history-substring-search` plugin — load fzf-tab
first; verify arrow-key history still works after.

---

## 7. shell — zoxide alongside (not replacing) wd

**Status:** ⬜ not started

**Why:** `wd` is manual bookmarks (`home`, `dot`, `ssh`… set in `_shell/shellenv:205-214`).
`zoxide` learns frequency/recency automatically — `z dotf<Tab>` jumps without
pre-registering. They coexist: keep `wd` for named stable jumps; add `z` for the long
tail.

**File:** `_shell/shellinteractive` (interactive only, both bash & zsh):

```sh
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init "$CURRENT_SHELL")"     # exposes z + zi (interactive, uses fzf)
fi
```

Missing tool — `zoxide = "latest"` in `mise/config.toml` (portable); optionally
`zoxide.pkg-path = "zoxide"` in the flox manifest on flox hosts. `~/.warprc` has grown to ~37 bookmarks
(2026-09-14), so `wd` is clearly the daily driver — keep this strictly additive.

## 12. shell — per-project env: prefer mise `[env]` over new direnv

**Status:** ⬜ not started (decision spike)

**Why:** The repo already runs pyenv + `.python-version` and a sophisticated mise
shim setup. `mise` natively provides direnv-style per-directory env loading via
`mise.toml` `[env]` blocks — so a new tool may be unnecessary. The tradeoff: mise env
loading requires `mise activate` (currently commented out at
`_shell/shellinteractive:150-158`), which would interact with the `MISE_DISABLE_TOOLS`
/ `_mise_disable_sync` exclusion machinery. Two clean options:

- **Enable `mise activate`** and lean on `[env]` for per-project vars — one tool, but
  verify it composes with the per-prompt `MISE_DISABLE_TOOLS` sync (test that shims
  and exclusions still behave).
- **Add standalone `direnv`** (`eval "$(direnv hook $shell)"`) and keep mise
  shim-only. Simpler blast radius, but a second tool doing overlapping work.

Decide as a small spike; **don't run both env hooks**. Given the care in the
shim-based mise design, standalone direnv is the lower-risk augmentation unless mise
`[env]` is specifically wanted.

---

## 3. git — delta pager (or difftastic)

**Status:** ⬜ not started

**Why:** Diffs currently go through plain `less`. `delta` gives syntax-highlighted,
line-level diffs and integrates conflict display (the repo already sets
`merge.conflictStyle = diff3` at `git/gitconfig:15-16`). Readability win on the
`logfull*` review workflow (`git/aliases`). Note: since the 2026 nvim work added
branch-review / line-history / richer blame to gitsigns, much diff *review* now
happens in nvim — so delta's marginal value is mainly for CLI `git show`/`git log`.

**File:** `git/gitconfig`.

```ini
[core]
    pager = delta
[interactive]
    diffFilter = delta --color-only
[delta]
    navigate = true
    line-numbers = true
[merge]
    conflictStyle = zdiff3       # upgrade from diff3 (Git >=2.35); cleaner conflicts
[diff]
    colorMoved = default
```

⚠️ Alternative: `difftastic` (structural/AST diff) as an on-demand `git dft` alias
rather than pager — better for refactors, slower, not a drop-in pager. Both missing →
`mise/config.toml` (portable), optionally also the flox manifest on flox hosts
(`delta.pkg-path = "delta"`, `difftastic.pkg-path = "difftastic"`).

## 6. git — workflow gaps to close

**Status:** ⬜ not started

Add to `git/gitconfig` / `git/aliases` (all augment the existing rich set):

```ini
# gitconfig
[rerere]
    enabled = true               # remember conflict resolutions -- big for rebase-heavy flow
[branch]
    sort = -committerdate        # most-recent branches first
[diff]
    algorithm = histogram        # better hunk matching than default myers
[fetch]
    prune = true                 # there is a `pruneall` alias; make fetch prune by default
[rebase]
    updateRefs = true            # stacked branches (Git >=2.38); pairs with rebase.autoStash
[column]
    ui = auto
```

```ini
# aliases -- worktree helpers (there are none today)
    wt = worktree
    wta = "!f(){ git worktree add ../$(basename $(git rev-parse --show-toplevel))-$1 -b $1; }; f"
    wtl = worktree list
    wtp = "!git worktree prune -v"
```

Surface existing tools: `_bin/git-fuzzy` and `_bin/git-visual-diff` exist but aren't
aliased — add `fz = !git-fuzzy` / `vd = !git-visual-diff` to `git/aliases` for
discoverability.

## 14. git — commit signing (SSH key)

**Status:** ⬜ not started

**Why:** Low effort, increasingly expected. Reuse the existing SSH key (no GPG):

```ini
[gpg]
    format = ssh
[user]
    signingkey = ~/.ssh/id_ed25519.pub
[commit]
    gpgsign = true
```

Put `signingkey` in `git/identity` / the `_sites/current` file (identity-specific).
⚠️ Verify the work GitLab accepts SSH signatures before enabling globally.

---

## 9. tmux — session management & copy hardening

**Status:** ⬜ not started

`tmux/tmux.conf` is excellent (clipboard toggle table, smart copy-mode, resurrect +
continuum). Gaps:

- **Fuzzy session/window switcher** — persistence exists but no fast switcher. Add
  `tmux-plugins/tmux-fzf` (via TPM, already the plugin manager), or a `prefix T`
  popup:
  ```tmux
  bind T display-popup -E "tmux list-sessions | sed 's/:.*//' | fzf --reverse | xargs tmux switch-client -t"
  ```
  (Or `sesh` — modern project-aware session manager, pairs with zoxide; currently missing.)
- **`extrakto`** — fzf grab of paths/urls/hashes from the pane; fits the
  clipboard-centric workflow.

⚠️ Clipboard is managed precisely via the `@clipboard_enabled` toggle table — audit
any new plugin's copy defaults before adding so they don't fight it.

## 10. nvim — telescope-fzf-native (low-risk, documented option)

**Status:** ⬜ not started

**Why:** `nvim/PICKER_NOTES.md` already lists this as "option 2, low-risk, preserves
Telescope UX." `rg` + `fzf` are installed; it is **not** wired in yet. Adds the native
fzf sorter → snappier sorting on large repos, zero UX change. Value rose now that
EDITOR is nvim.

**File:** `nvim/lua/plugins/telescope.lua` — add dependency
`nvim-telescope/telescope-fzf-native.nvim` (`build = "make"`) and
`require('telescope').load_extension('fzf')`. Smallest possible nvim change.

## 11. nvim — Python DAP (deferred Milestone 5)

**Status:** ⬜ not started (standing deferral — decision required)

**Why:** The explicitly-deferred decision in `nvim/DEBUGGING_PYTHON.md` (renamed from
`DEBUGGING_NOTES.md`). Current flow is terminal-first `python -m ipdb` via `SPC dd` /
`,dd`; the notes reaffirm this is intentional (terminal-first, SSH-friendly) and DAP
is deferred for its maintenance cost. For gutter breakpoints + locals/stack panes:
`mfussenegger/nvim-dap` + `mfussenegger/nvim-dap-python` + `rcarriga/nvim-dap-ui` +
`theHamsta/nvim-dap-virtual-text`. Wire under the existing `SPC d` group. Reuse the
pyenv interpreter resolution in `nvim/lua/config/python.lua` to point dap-python at
the right `debugpy`. The one medium-effort item — a real feature, decided per the
notes (adopt only if terminal-only stepping becomes frequent friction).

## 15. nvim — optional modern swaps (⚠️ fight stability preference)

**Status:** ❌ blink.cmp rejected (decision recorded in `nvim/TODO_REFACTORING.md`
§3, 2026-09-13: "nvim-cmp over blink.cmp or native `vim.lsp.completion` … Revisit
only when nvim-cmp breaks"). ⬜ trouble.nvim / fidget remain optional additions.

Shown for completeness:
- **blink.cmp** replacing nvim-cmp — faster, but there's a finely-tuned
  quiet/manual/full completion-mode system (`nvim/lua/config/completion.lua`) that
  relies on cmp's `debounce` and re-`setup` semantics; blink has no user debounce.
  Same file also rejects snacks.picker/fzf-lua in favor of Telescope, which keeps
  #10 (telescope-fzf-native) as the only picker-performance item.
- **trouble.nvim** — persistent diagnostics panel; Telescope covers this today.
  Low-risk *addition* if a pinned list is wanted.
- **fidget.nvim** — LSP progress spinner; trivial, cosmetic.

---

## 13. shell — atuin (⚠️ history swap, evaluate carefully)

**Status:** ⬜ not started (conditional — only if cross-machine sync wanted)

**Why considered:** SQLite-backed fuzzy history with optional E2E-encrypted sync,
per-directory/per-host context. Strictly more powerful than zsh `share_history` +
`history-substring-search` + fzf `CTRL-R`.

**Why ⚠️:** genuine *swap* — takes over `CTRL-R` and up-arrow, moves history to its
own DB, overlaps the tuned `FZF_CTRL_R_OPTS`. Worth it **only if** cross-machine
history sync is wanted (work laptop ↔ servers). Single-machine → the fzf `CTRL-R` is
already excellent; skip. If adopted, self-host or disable the sync server given the
security posture (`_bin/hibp-check-password`, OSC52 care, ForwardAgent off).

---

## 16. shell — startup: three no-op Python calls cost ~220 ms (new 2026-09-14)

**Status:** ⬜ not started

**Why:** `zsh -i -c exit` measures ≈ 0.53 s on the host. A timestamped xtrace
shows the single largest cost is **not** OMZ (≈ 30 ms) or compinit (≈ 9 ms) but
`_sites/work/_shell/shellenv`, which calls `path-insert` three times (PATH,
MANPATH, PKG_CONFIG_PATH) with **empty** `new_*` arrays. `path-insert` is a Python
script (`_bin/path-insert`) reached through the pyenv shim, so each call is a full
interpreter start: ≈ 73 ms × 3. Everything else is small change.

**File:** `_sites/work/_shell/shellenv` (site repo). Guard each call:

```sh
if [ ${#new_path[@]} -gt 0 ]; then
    export PATH="$(path-insert '.*/\.npm-packages/bin$' "$(join : ${new_path[@]})" "$PATH")"
fi
```

(Same for `new_manpath` / `new_pkg_config_path`.) If the arrays are empty on every
host, delete the block outright. Alternatively re-implement `path-insert` as a shell
function in `_shell/shellenv` so it is free even when non-empty.

**Second-order (optional, ~70 ms more):**
- `kubectl completion zsh` (`_shell/shellinteractive:242-248`, ≈ 36 ms) → cache to
  `${XDG_CACHE_HOME:-~/.cache}/kubectl-completion.$CURRENT_SHELL`, regenerate when
  the file is older than the `kubectl` binary.
- Six `cd … && wd -q add!` calls at every shell start (`_shell/shellenv:211-218`,
  ≈ 33 ms) rewrite `~/.warprc` each time. `~/.warprc` is already a plain
  `name:path` file — seed those six entries once from `_bin/dotfiles-install` and
  drop the loop (wd tolerates entries whose directory doesn't exist).
- `pyenv init` + `pyenv virtualenv-init` (≈ 53 ms) — already trimmed by
  `--no-rehash` (`71a9ad6`, 2026-09-13); the rest is inherent to pyenv.

**Out of scope but visible:** `/etc/profile.d/system-restart-check.sh`
(`needs-restarting --reboothint`, ≈ 92 ms) is the host's root-owned profile script,
not the dotfiles'. It is the single largest remaining line after #16. To re-measure
after any change:

```sh
PS4='+%D{%s.%6.} %N:%i> ' zsh -i -x -c exit 2> /tmp/zsh-trace.txt
awk 'match($0,/^\++([0-9]+\.[0-9]+) (.*)$/,m){t=m[1]; if(prev!=""){d=t-prev; if(d>0.008) printf "%.3f  %s\n", d, prevline}; prev=t; prevline=substr(m[2],1,140)}' /tmp/zsh-trace.txt | sort -rn | head -20
```

## 17. fzf — provider cleanup (new 2026-09-14)

**Status:** ⬜ not started

**Why:** fzf now resolves to the **mise shim (0.71.0)** because `_shell/shellenv:168`
prepends `$MISE_DATA_DIR/shims`. The `fzf/install` run from Jan 2026 left an
untracked **0.67.0 binary in `_lib/fzf/bin/`**, which `~/.fzf.zsh` appends to the
*end* of PATH — dead weight that never runs, while the submodule source itself is at
v0.74.4 (so its `fzf-tmux` script is newer than the binary it drives).
`_bin/dotfiles-install:163` still says "remember to run fzf/install", which would
re-download another binary PATH ignores.

**Fix (tiny):**
- `rm _lib/fzf/bin/fzf` (untracked; `bin/fzf-tmux` and `bin/fzf-preview.sh` are
  tracked and stay).
- Bump `fzf = "0.71.0"` in `mise/config.toml` to the submodule's tag (0.74.x) so
  binary and `fzf-tmux` match; keep `policy[fzf]=newer`.
- Change the `dotfiles-install` fzf step to write `~/.fzf.zsh`/`~/.fzf.bash` only
  (or `fzf/install --no-bin --no-update-rc` style) — the shell hooks are just
  `source <(fzf --zsh)` and need no binary download.

## 18. shell — mise/flox hygiene (new 2026-09-14)

**Status:** ⬜ not started

Small, mechanical, all low-risk:

- **mise orphans:** `mise-all ls` shows `terraform-docs 0.20.0`, `terraformer
  0.8.30`, `terragrunt 0.87.5`, `tfupdate 0.9.2`, `tflint 0.59.1`, `pre-commit
  4.3.0` installed but not in `mise/config.toml` (the tf* pins are commented out),
  while `pre-commit 4.5.1` is pinned but *missing*. `mise install && mise prune`
  reconciles. If the tf* tools are meant to be system-provided, the commented
  `= "system"` lines belong in `check-tools`' `policy` table, not `config.toml`.
- **Two flox lists drift:** `_reqs/flox-al2.txt` (shared repo, 2026-09-13) lacks
  `chafa`, `gcc`, `glow`, `mc` and has an older `glab` than
  `_sites/work/flox/flox.list` (site repo, 2026-08-25). Pick one as canonical, or
  regenerate `_reqs/flox-al2.txt` from `flox list` in the same commit that touches
  the manifest.

---

## What to deliberately NOT change

- **OMZ → zinit/antidote:** OMZ is ≈ 30 ms of a ≈ 530 ms startup (profiled
  2026-09-14); the real cost is external commands (#16). Auto-update is off. Keep OMZ.
- **Custom `kyle` theme → starship:** intentional and fast; starship is a lateral move.
- **Telescope → fzf-lua:** `nvim/PICKER_NOTES.md` already concluded Telescope suffices;
  fzf-native (item 10) gets the speed without the rewrite.
- **eza/lsd → ls:** the `LS_COLORS` + aliases are dialed in; cosmetic at best.
- **mise shim model → full activate:** don't undo the `MISE_DISABLE_TOOLS` design
  casually — only revisit if adopting mise `[env]` (item 12).

---

## Verification (per item, when implemented)

- **SSH multiplexing (#1):** `ssh -v host` first connect shows auth; second shows
  `mux_client_request_session: master complete` / instant. `ssh -O check host`.
- **fzf backends (#2/#8):** `echo $FZF_DEFAULT_COMMAND`; new shell, `CTRL-T` in a
  large repo lists fast, respects `.gitignore`; preview renders via bat.
- **fzf-tab (#4):** new shell, `cd <Tab>` shows fzf menu + preview; confirm
  history-substring up-arrow unaffected.
- **delta (#3):** `git show HEAD` renders highlighted; `git diff` uses delta.
- **git config (#6):** `git config --get rerere.enabled`; throwaway rebase confirms
  `updateRefs`/`autoStash`.
- **zoxide (#7):** new shell, `z <partial>` jumps.
- **mise `[env]` vs direnv (#12):** confirm only one env hook active; shims +
  exclusions still behave (`mise-refresh`, `MISE_DISABLE_TOOLS` intact).
- **nvim telescope-fzf-native (#10):** `:checkhealth telescope` shows fzf loaded.
- **nvim DAP (#11):** breakpoint → `SPC d` run → stop + locals pane on a sample pytest.
- **tmux (#9):** `prefix T` opens session picker; clipboard toggle table still works after.
- **startup (#16):** `time zsh -i -c exit` drops by ≥ 0.2 s; the xtrace in #16 shows no
  `path-insert` line above 8 ms.
- **fzf cleanup (#17):** `command -v fzf` → mise shim; `fzf --version` equals the
  `_lib/fzf` tag; `fzf-tmux` still launches.
- **hygiene (#18):** `mise-all ls` shows no `(missing)` and no unpinned rows.

## Suggested implementation order

0. Startup guard for empty `path-insert` (#16) — a three-line `if` in the site
   shellenv, ~0.2 s back on every shell; do it first because it is the cheapest.
1. SSH multiplexing + keepalive (#1, #5) — instant daily payoff, config-only.
2. fzf backends + install fd/bat (#2, #8) — mise-install tools, wire env.
3. git delta + config hygiene + worktree aliases (#3, #6) — install delta, edit gitconfig.
4. fzf-tab + zoxide (#4, #7) — submodule/mise adds + zshrc/shellinteractive.
5. nvim telescope-fzf-native (#10) — one-line plugin spec.
6. tmux session picker (#9).
7. Spikes/decisions: mise `[env]` vs direnv (#12), nvim DAP (#11), atuin (#13).
8. Hygiene sweep when convenient (#17, #18) — each is a single small commit.

Each is independent and individually revertible (matches the modular, sourced-file
design). No item requires touching another to land.

---

## Appendix — Reassessment 2026-07-29

Reassessment of the 2026-06-01 backlog after ~2 months of work. Repo moved from
commit `e83e005` (2026-06-01) to `d185bcd` (2026-07-29); ~40 in-scope commits landed
in between.

### The gap is lopsided
All ~40 in-scope commits are in **`nvim` (majority), `tmux`, `mise`, and `_shell`**.
The four areas holding the highest-value recommendations — **`ssh`, `git` config,
`fzf`, `zsh`** — received **zero commits**. The top of the priority list is entirely
intact and untouched.

### Still valid (re-verified 2026-07-29)
| # | Item | Status now |
|---|------|-----------|
| 1 | SSH ControlMaster multiplexing | `ssh/config` still 12 lines, `ControlMaster` count = 0. **Still #1, untouched.** |
| 2 | fzf `FZF_DEFAULT_COMMAND` via rg/fd | Still unset — fzf still uses its slow built-in walker. Valid. |
| 3–6, 14 | git delta, rerere, worktree, signing | `git/` untouched. All valid. |
| 4 | fzf-tab for zsh | `zsh/` untouched. Valid. |
| 7 | zoxide alongside wd | Not adopted. Valid. |
| 8 | fd + bat | Both still MISSING. Valid. |
| 10 | telescope-fzf-native | Still absent — and value rose (EDITOR is now nvim). |
| 11 | Python DAP | Still absent; `DEBUGGING_PYTHON.md` reaffirms the deliberate terminal/ipdb choice. Standing deferral, not a gap. |

### What changed, and its effect on the backlog
- **EDITOR → nvim** (`11f1e0b`, 2026-06-30; was `emacsclient -a vim`). Center of
  gravity moved to nvim → *raises* payoff of #10 and #11.
- **nvim git workflow got much richer** — branch-review mode, line-history, richer
  blame, cyclable gitsigns diff base, `SPC gM`, full Magit-style gitrebase keys. Diff
  *review* increasingly lives in nvim → *lowers* the marginal value of CLI **git
  delta** (#3), though still worth it for `git show`/`log`.
- **mise `check-tools` reworked into a data-driven skip engine** (`b1e77d8`,
  2026-07-01: system/newer/mise policy table, provider hierarchy, shims-aware). Makes
  the shim-based mise design even more load-bearing → reinforces the #12 guidance
  (prefer standalone direnv over disturbing `mise activate`).
- **tmux** got winsize-resync-on-reattach (`d185bcd`) and selective mouse-copy-exit
  (`7234307`) — refinements to the already-excellent copy/clipboard system. #9
  (session picker, extrakto) unaffected and still additive.

### Net verdict
Nothing on the backlog is invalidated. The highest-value items (SSH multiplexing, fzf
backends, git config hygiene, fzf-tab) are exactly as applicable as on 2026-06-01 —
those areas simply weren't touched. The two months of work went almost entirely into
nvim polish (plus the mise engine), which *strengthens* the case for the nvim-side
items and confirms the DAP deferral is a real, standing decision.

---

## Appendix — Reassessment 2026-09-14

Repo moved from `3915c7e` (2026-07-29, the commit that added this file) to
`71a9ad6` (2026-09-13); 66 commits. Verified on the AL2 host itself (an earlier
pass from a sandbox mirroring `$HOME` reported `tree` missing; the host has it as an
rpm, so that item was withdrawn before this file was saved).

### The gap is still lopsided — more so
Of 66 commits, **54 are `nvim`** (a full refactoring pass driven by
`nvim/TODO_REFACTORING.md`), plus 3 `claude`, 2 `tmux`, 1 each of `shell`, `mise`,
`lib`, `flox`, `gitignore`, `docs`, `ai`. **`ssh/`, `git/`, `zsh/`, and the fzf block received zero
commits.** `ssh/config` is still 12 lines; `git/gitconfig` still `diff3`, no
`rerere`, no worktree aliases; `FZF_DEFAULT_COMMAND` still unset. Items #1–#8 and
#14 are exactly as applicable as on 2026-06-01.

### Still valid (re-verified 2026-09-14)
| # | Item | Status now |
|---|------|-----------|
| 1, 5 | SSH ControlMaster, keepalive | `ssh/config` unchanged. OpenSSH 7.4p1 supports every recommended key. **Still #1.** |
| 2, 8 | fzf backends; fd + bat | `FZF_DEFAULT_COMMAND` unset; fd/bat still missing. Valid; install route is now flox-first. |
| 3, 6, 14 | git delta, rerere/worktree/sort, signing | `git/` unchanged (git 2.47.3 supports all keys). Valid. |
| 4 | fzf-tab | `zsh/zshrc` unchanged; plugin list identical. Valid. |
| 7 | zoxide alongside wd | Not adopted; `~/.warprc` now ~37 entries, wd is clearly primary. Valid, strictly additive. |
| 9 | tmux session picker, extrakto | tmux.conf changed only in the reattach-resize hook (now `M-r` key, `99870a8`) and double/triple-click (`copy-mode -H`, `66aad12`). Plugins still tpm/resurrect/continuum/yank. Valid. |
| 10 | telescope-fzf-native | Still absent. `TODO_REFACTORING.md` re-affirmed Telescope over snacks.picker/fzf-lua, so this stays the only picker-perf item. |
| 11 | Python DAP | Still absent; `DEBUGGING_PYTHON.md` unchanged. Standing deferral. |
| 12 | mise `[env]` vs direnv | Unchanged — and `flox activate` is *also* deliberately off, so there are now three env-hook mechanisms all disabled by design. Standalone direnv remains the lowest-risk route. |
| 13 | atuin | Unchanged; conditional. |
| 15 | blink / trouble / fidget | **blink.cmp now ❌** — explicitly rejected in `TODO_REFACTORING.md` §3. trouble/fidget still optional. |

### What changed, and its effect on the backlog
- **The binary hierarchy is now explicit and per-host:** system packages → flox
  (on hosts that use it) → mise → homedir builds (`~/.local`, `~/.root`).
  `check-tools` implements exactly this. On this host flox supplies rg, nvim, glab,
  yq, mc, glow and more via plain PATH entries (not `flox activate`); on non-flox
  hosts mise fills that role. → **Install instructions in #2/#3/#7/#8 were stale
  ("`mise use -g`") and now say: `mise/config.toml` as the portable list, flox
  manifest optionally on flox hosts.** The "Repo conventions" section describes the
  hierarchy.
- **fzf moved from the submodule download to the mise shim** (0.67.0 → 0.71.0)
  because shims are prepended to PATH. The old binary is orphaned → new #17.
- **`pyenv init --no-rehash`** (`71a9ad6`) shows startup time is on the owner's
  mind. Profiling found the dominant cost is three no-op Python `path-insert` calls
  in the site shellenv (~220 ms) → new #16, and the "keep OMZ" rationale was
  corrected (OMZ is ~30 ms, not the bottleneck).
- **mise orphans and two drifting flox lists** → new #18.
- **nvim: 54 commits of refactoring** (lsp.lua split into four modules, tool
  probes centralised in `config/tools.lua` and cached per PATH, dependency audit
  moved to `:checkhealth`, mason-lspconfig dropped, git listings batched/backgrounded,
  Oil git-status column, project-wide diff-base change lists). None touch the
  backlog items, but two recorded decisions do: Telescope stays (reinforces #10 as
  the right shape) and nvim-cmp stays (#15 blink → ❌).
- **Uncommitted WIP** (`nodejs/npmrc`, `poetry/config.toml`, `terraform/terraformrc`,
  `mc/ini`) is internal-mirror configuration — unrelated to this backlog, left alone.

### Net verdict
Nothing in the original ranking is invalidated; the top four items are untouched
and still the highest value. Three small items were added (#16–#18), of which **#16
is the only one with a measured payoff** (~0.2 s per shell start for a three-line
guard) and should go first. The install mechanism text was the one genuinely stale
part of the doc and has been corrected for the per-host provider hierarchy.
