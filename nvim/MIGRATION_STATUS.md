# Neovim Migration Status

Last updated: 2026-04-19

## Goal

Replace the current Spacemacs coding workflow with a native Neovim setup that
preserves modal editing, leader-key discovery, coding/navigation workflows, git,
tests, terminals, and the highest-value Spacemacs/Evil behavior.

## Current Baseline

- Config root: `~/.dotfiles/nvim`
- Live symlink: `~/.config/nvim -> ../.dotfiles/nvim`
- Current baseline commits:
  - `2e74f1b` `Add Spacemacs-style Neovim config`
  - `c004ceb` `Improve Neovim Python env and dependency checks`
  - `5fc01c5` `Tighten Neovim keybindings and tool setup`
  - `fdef8bc` `Add Neovim migration status file`
  - `cebe770` `Add Evil-style jump and surround behavior`

## Completed

- Spacemacs-style leader layout with `SPC` and `,`
- Modal editing with core Evil-like behavior
- Telescope search and project grep
- Neo-tree file explorer
- Neogit and gitsigns
- LSP-first navigation with GNU Global fallback
- Python pyenv-aware interpreter selection
- Python linting, formatting, and tests wired to the active environment
- Multiple cursors
- Outline/symbol sidebar
- Terminal integration
- HTTP file support
- Dependency auditing with `:NvimDeps`
- Non-Python language tools installed and visible to Neovim
- Automatic formatting on save removed; formatting is manual-only via `SPC c f`
- Localleader popup support restored through `which-key`
- Spacemacs-style code-buffer localleader navigation restored:
  - `,gg` definition
  - `,gb` jump back
  - `,gi` implementation
  - `,gr` references
  - `,gs` workspace symbols
  - `,hh` hover/docs
  - `,rr` rename
  - `,aa` code action
  - `,=b` format buffer manually
- Evil-feel pass completed:
  - jump plugin
  - surround-style bindings
  - visual-selection search
  - tighter special-buffer close behavior
- Projectile-style project switching completed:
  - recent project registry
  - `SPC p p` project switcher
  - `SPC p r` recent projects
  - `SPC p a` add current project
  - `SPC p d` remove current project
  - session-aware project switching

## Guardrails

- Do not enable automatic formatting on save for Python or other languages
- Keep formatting as an explicit action through `SPC c f` or `:ConformInfo`

## Alignment TODOs

- Keep auditing code-mode `SPC m` and `,` bindings against Spacemacs defaults; `,gg` is restored, but more localleader parity checks may still be needed
- Keep checking localleader `which-key` coverage in filetype-specific buffers so `,` remains discoverable everywhere it matters

## Missing Or Partial

- Emacs-native long tail is still unported:
  - heavy Org integrations
  - Elfeed
  - PDF workflow
  - IETF/xkcd/speed-reading layers
  - some secondary language/tooling layers

## Next Milestones

- Milestone 3: continue Spacemacs parity audit
  - review remaining code-mode localleader bindings
  - keep localleader `which-key` coverage consistent across filetypes
  - decide which Emacs-native long-tail layers matter enough to port

## Validation Baseline

- `nvim --headless '+qa'`
- `nvim --headless '+Lazy! load all' '+qa'`
- `:NvimDeps` reports all checked dependencies installed
