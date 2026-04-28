# iTerm2 Font Setup

## Install Nerd Font

```sh
~/.dotfiles/nerdfonts/install
```

This installs `SauceCodePro Nerd Font Mono` to `~/Library/Fonts/nerd-fonts/sauce-code-pro/`.
macOS auto-discovers fonts in `~/Library/Fonts/`.

## Configure iTerm2

1. Open iTerm2
2. **iTerm2 > Settings > Profiles** (tab bar)
3. Select your active profile
4. Click the **Text** tab
5. Click **Font** and choose **Change Font...**
6. Search for **SauceCodePro Nerd Font Mono**
7. Set size to **12**

## Glyphs

After setup, icon glyphs render correctly in iTerm2, tmux, SSH sessions, and TUI programs.

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

