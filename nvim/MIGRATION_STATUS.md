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
- Evil-feel pass completed:
  - jump plugin
  - surround-style bindings
  - visual-selection search
  - tighter special-buffer close behavior

## Guardrails

- Do not enable automatic formatting on save for Python or other languages
- Keep formatting as an explicit action through `SPC c f` or `:ConformInfo`

## Missing Or Partial

- Projectile-style project switching is still partial:
  - no recent-project switcher
  - no explicit project add/remove commands
  - sessions exist, but project switching is not first-class yet
- Emacs-native long tail is still unported:
  - heavy Org integrations
  - Elfeed
  - PDF workflow
  - IETF/xkcd/speed-reading layers
  - some secondary language/tooling layers

## Next Milestones

- Milestone 2: add projectile-style project switching
  - project switcher
  - recent projects
  - project commands under `SPC p`
  - session/project workflow cleanup

## Validation Baseline

- `nvim --headless '+qa'`
- `nvim --headless '+Lazy! load all' '+qa'`
- `:NvimDeps` reports all checked dependencies installed
