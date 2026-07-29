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
- **Reassessment: 2026-07-29** (repo at commit `d185bcd`) — see the Appendix. All
  ground-truth below was re-verified on 2026-07-29 and remains accurate.

### Ground-truth (verified 2026-07-29)
- **Installed:** `ripgrep 15.1.0`, `fzf 0.67.0`, `mise 2026.4.5`, `pygmentize`, `tmux`.
- **Missing:** `fd`, `bat`, `delta`, `difftastic`, `eza`/`lsd`, `zoxide`, `atuin`, `direnv`, `starship`, `sesh`.
- **SSH:** no ControlMaster multiplexing (`ssh/config` is 12 lines: EscapeChar + ForwardAgent/X11 off) despite a socks-`ProxyCommand` work setup — highest-latency win.
- **fzf:** `FZF_DEFAULT_COMMAND` unset → fzf uses its slow built-in walker and ignores `.gitignore`, even though `rg` is installed.
- **mise:** deliberately **shim-based, not `eval`-activated** — `mise activate` is commented out (`_shell/shellinteractive:150-158`) in favor of a custom `MISE_DISABLE_TOOLS` exclusion system with per-prompt cached sync (`_mise_disable_sync`, `mise-refresh`, `mise-all`, `_shell/shellinteractive:160-202`; `_shell/shellenv:165-174`). This is intentional and sophisticated — see item #12. Reworked into a data-driven skip engine on 2026-07-01 (commit `b1e77d8`).
- **nvim:** nvim-cmp + Telescope with **no** telescope-fzf-native (absent) and **no** nvim-dap (absent) — both match the documented `PICKER_NOTES.md` / `DEBUGGING_PYTHON.md` deferrals.
- **EDITOR is now `nvim`** (`_shell/shellinteractive:65`; switched 2026-06-30, commit `11f1e0b`) — raises the payoff of the nvim-side items.

### Repo conventions a fresh agent needs
- **Install model:** symlink-based via `_bin/dotfiles-install` (Python); external tools pinned as **git submodules under `_lib/`**. New CLI tools can also come from **`mise use -g <tool>`** (mise is installed and manages a tool set; see `mise/check-tools`).
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
| 15 | nvim: blink.cmp, trouble.nvim, fidget | nvim | ★★☆☆☆ | medium | ⚠️ swap | ⬜ |

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
**Install mechanism:** `fd`/`bat` fit the mise story — `mise use -g fd bat` — or pin
as `_lib/` submodules. Note Debian's packages expose `fdfind`/`batcat`; if using the
distro-package route, alias them in `_shell/shellenv`. Decide during implementation.

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

Missing tool — `mise use -g zoxide` fits the existing mise setup.

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
`mise use -g delta difftastic` or submodule.

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

**Status:** ⬜ not started (not recommended now)

Shown for completeness:
- **blink.cmp** replacing nvim-cmp — faster, but there's a finely-tuned
  quiet/manual/full completion-mode system (`nvim/lua/config/completion.lua`) to
  re-port.
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

## What to deliberately NOT change

- **OMZ → zinit/antidote:** startup isn't the bottleneck; auto-update is off. Keep OMZ.
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

## Suggested implementation order

1. SSH multiplexing + keepalive (#1, #5) — instant daily payoff, config-only.
2. fzf backends + install fd/bat (#2, #8) — mise-install tools, wire env.
3. git delta + config hygiene + worktree aliases (#3, #6) — install delta, edit gitconfig.
4. fzf-tab + zoxide (#4, #7) — submodule/mise adds + zshrc/shellinteractive.
5. nvim telescope-fzf-native (#10) — one-line plugin spec.
6. tmux session picker (#9).
7. Spikes/decisions: mise `[env]` vs direnv (#12), nvim DAP (#11), atuin (#13).

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
