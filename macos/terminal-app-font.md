# Terminal.app Font Setup

## Install Nerd Font

```sh
~/.dotfiles/nerdfonts/install
```

This installs `SauceCodePro Nerd Font Mono` to `~/Library/Fonts/nerd-fonts/sauce-code-pro/`.
macOS auto-discovers fonts in `~/Library/Fonts/`.

## Configure Terminal.app

1. Open Terminal.app
2. **Terminal > Settings > Profiles** (tab bar)
3. Select your active profile
4. Click **Text** tab
5. Click **Font > Change...**
6. Search for **SauceCodePro Nerd Font Mono**
7. Select it and set size to **12**

## Glyphs

After setup, emoji and icon glyphs (from powerlevel10k, devicons, etc.) render correctly
in Terminal.app, tmux, SSH sessions, and Neovim/TUI programs.

## Mouse Selection in tmux

tmux's mouse mode captures all mouse events, so you cannot select text by clicking and dragging
inside tmux panes. Use these alternatives:

**Copy-mode** (recommended):
- `prefix + [` — enter scrollback / copy-mode
- `y` — yank selection to macOS clipboard (via tmux-yank plugin)
- `M-y` — yank to clipboard with display message
- `q` — exit copy-mode
- `v` / `C-v` — begin / rectangle selection in vi mode

**Toggle mouse mode**:
- `prefix + M` — disable mouse mode, raw iTerm2 selection works
- `prefix + m` — re-enable mouse mode

**Pane navigation without mouse**:
- `prefix + o` — next pane
- `prefix + direction keys` — move between panes

