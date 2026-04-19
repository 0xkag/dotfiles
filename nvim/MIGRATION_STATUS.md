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
  - `215d3d0` `Add project switching and localleader parity`
  - `0bbd3cc` `Port Vim behavior and themes to Neovim`
  - `e87d67e` `Finish Vim cleanup mappings`

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
- Vim baseline behavior pass completed:
  - global indent default returned to 4, with explicit per-language overrides
  - `set list` restored globally
  - old listchars toggle paths restored on `SPC t v t`, `SPC t v a`, and `SPC t v u`
  - `showbreak` restored for wrapped lines
  - insert-mode Emacs-style keys restored
  - visual `.` repeat restored
  - visual `%s` helper restored on `<leader>%`
  - `autoread`, dictionary, and spelling suggestions restored
  - `*.bin` xxd editing workflow restored
  - legacy clipboard fallback shell commands ported as disabled comments
  - legacy `t_BE` tweak ported as a disabled comment
  - `ron` and `cyberpunk` colorschemes ported as selectable Neovim themes
- Spacemacs code-mode parity first pass completed for primary coding workflows:
  - shared LSP localleader prefixes expanded under `,g`, `,F`, `,a`, `,b`, `,=`, `,x`, and `,T`
  - Python test aliases added under `,t`
  - Go localleader helpers added for alternate test/source, imports, tests, run, and generate
  - Java localleader helpers added for alternate test/source, build, tests, task execution, and imports
  - shell-script helpers added for shebang/template insertion and line-continuation backslashes
- Spacemacs code-mode parity second pass completed for secondary workflows:
  - Markdown localleader helpers added for headings, links, images, tables, emphasis, blockquotes, and rendered preview/toggles
  - Terraform localleader helpers added for validate, lint, and formatting checks without enabling autoformat on save
- Spacemacs code-mode parity follow-up pass completed for shared aliases:
  - shared LSP aliases now cover Java-style project diagnostics, execute action, restart workspace, project-type search, and reference/type-definition shortcuts
  - Go coverage summary is available under localleader without adding extra external tooling
- Reading-focused code-browsing pass completed for mixed-language inspection:
  - shared LSP localleader now includes incoming/outgoing call hierarchy helpers
  - shared LSP localleader now includes subtype/supertype hierarchy helpers for servers that support type hierarchy
- Python debugging baseline completed:
  - Python debug commands now use the resolved pyenv interpreter instead of assuming a global Python
  - missing `ipdb` now shows up explicitly in dependency checks for Python buffers
  - leader and localleader debug commands are available for file-level and pytest-based debugging
- Python debugging options documented:
  - current terminal/ipdb flow, lightweight gutter-breakpoint option, and full DAP tradeoffs are written down in `~/.dotfiles/nvim/DEBUGGING_NOTES.md`
- Vim parity follow-up completed:
  - restored `showmatch`, `lazyredraw`, and the old `timeoutlen`
  - restored command-line and normal-mode `Ctrl-a` / `Ctrl-e` home/end behavior
  - restored legacy clipboard yank aliases on `SPC C` and `SPC Y`
  - blended the sign column with the normal background for closer Vim-era visuals
- Theme review helper added:
  - `:ThemeReview` opens Python, Markdown, and diff fixtures for interactive review of `cyberdream`, `ron`, and `cyberpunk`
  - textual comparison found the `ron` and `cyberpunk` ports faithful overall, with `SignColumn` intentionally blended into `Normal` to match the old Vim setup

## Guardrails

- Do not enable automatic formatting on save for Python or other languages
- Keep formatting as an explicit action through `SPC c f` or `:ConformInfo`

## Alignment TODOs

- Keep auditing code-mode `SPC m` and `,` bindings against Spacemacs defaults; `,gg` is restored, but more localleader parity checks may still be needed
- Keep checking localleader `which-key` coverage in filetype-specific buffers so `,` remains discoverable everywhere it matters
- Review the existing `~/.dotfiles/vim` config against Neovim and classify each behavior as:
  - already matched
  - intentionally different
  - missing and worth porting

## Missing Or Partial

- Native Vim-to-Neovim parity still needs a final visual review:
  - old clipboard fallback aliases are preserved only as disabled reference comments
  - exact theme parity still needs a real interactive visual review of `ron` and `cyberpunk` inside Neovim
  - Neovim intentionally leaves global `textwidth` unset, unlike the old Vim `textwidth=78`, to avoid surprise wrapping in code buffers
- Spacemacs code-mode parity is still partial:
  - advanced Go helpers like go-play, graphical coverage views, test generation, and deeper refactors are still missing
  - advanced Java generator/refactor actions from the old Java layer are only loosely approximated through LSP actions
  - markdown and terraform now have a useful localleader baseline, but many niche layer-specific actions are still intentionally omitted
  - some `lsp-ui`/peek-style overlays are still approximated with Telescope or quickfix rather than recreated exactly
  - Python debugging is terminal/ipdb oriented rather than a full DAP UI stack
- Emacs-native long tail is still unported:
  - heavy Org integrations
  - Elfeed
  - PDF workflow
  - IETF/xkcd/speed-reading layers
  - some secondary language/tooling layers

## Next Milestones

- Milestone 3: continue secondary Spacemacs code-mode parity
  - decide which advanced Go and Java helpers are worth implementing versus leaving behind
  - keep auditing `,` menus for gaps in daily Python, Go, Java, shell, and mixed-language workflows
  - decide whether any additional Markdown or Terraform actions are worth the maintenance cost beyond the current baseline
- Milestone 5: decide whether Python debugging should stay terminal/ipdb based or grow into full DAP support
  - keep the dependency reporting explicit either way
  - only add a DAP stack if you decide the extra UI and moving parts are worth it
- Milestone 4: finish Vim parity review
  - interactively inspect `ron` and `cyberpunk` in your real terminal
  - decide whether the old clipboard fallback aliases should remain comments or become an optional toggle
  - decide whether any remaining old Vim aliases should come back as active mappings

## Validation Baseline

- `nvim --headless '+qa'`
- `nvim --headless '+Lazy! load all' '+qa'`
- `:NvimDeps` reports all checked dependencies installed
