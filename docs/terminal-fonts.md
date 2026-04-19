# Terminal Nerd Font Wiring

## Summary

The correct place to solve terminal glyph rendering is the **client terminal**
that actually draws text on screen.

- `tmux` does not render fonts
- `ssh` does not render fonts
- Neovim does not render fonts

So the same fix applies locally, over tmux, and over SSH:

1. install a Nerd Font on the client machine
2. configure the client terminal emulator to use it

For the current dotfiles, the chosen family is:

- `SauceCodePro Nerd Font Mono`

That is the Nerd Fonts Source Code Pro variant, using the **Mono** build so
glyphs stay single-width in terminal grids.

## What The Dotfiles Now Configure

### Linux GUI terminals

The GNOME Terminal snapshot in
[gnome-terminal.dconf](/home/kag/.dotfiles/gnome/gnome-terminal.dconf:1) now
requests:

- `font='SauceCodePro Nerd Font Mono 12'`
- `use-system-font=false`

That setting applies after reloading the saved dconf profile with
[gnome/load](/home/kag/.dotfiles/gnome/load:1).

### Windows Terminal

[windows-terminal-settings.json](/home/kag/.dotfiles/wsl/windows-terminal-settings.json:1)
now sets:

- `profiles.defaults.font.face = "SauceCodePro Nerd Font Mono"`

That means Windows Terminal will use the Nerd Font once it is installed in
Windows.

### Linux font install helper

The installer in
[_bin/dotfiles-install](/home/kag/.dotfiles/_bin/dotfiles-install:1) still
installs the existing plain Source Code Pro assets, and is now also
future-ready for an optional vendored Nerd Font payload at:

- `~/.dotfiles/_lib/sauce-code-pro-nerd-font`

If that directory exists, the installer will symlink it into:

- `~/.local/share/fonts/nerd-fonts/sauce-code-pro`

and refresh the font cache.

The repo does **not** currently vendor the Nerd Font binaries.

## What Still Has To Be Installed Manually

### Linux desktop

Install `SauceCodePro Nerd Font Mono` on the Linux machine that runs your GUI
terminal.

You can do that either by:

- installing it from your distro packaging if available
- or placing the extracted font files under a local font directory
- or vendoring the font under `~/.dotfiles/_lib/sauce-code-pro-nerd-font` and
  rerunning `dotfiles-install`

If you install it manually, refresh fontconfig with:

```sh
fc-cache -f -v
```

### Windows Terminal

Install the same Nerd Font in Windows itself. Windows Terminal only works once
the Windows font registry knows about the family.

After that, merge or copy the settings fragment from
[windows-terminal-settings.json](/home/kag/.dotfiles/wsl/windows-terminal-settings.json:1)
into your real Windows Terminal settings.

## tmux And SSH

No tmux-specific or SSH-specific font configuration is needed.

If the **client** terminal uses `SauceCodePro Nerd Font Mono`, then:

- local shells render correctly
- tmux panes render correctly
- remote SSH sessions render correctly
- remote Neovim/TUI programs render correctly

The outer terminal is the only place that needs the font.

## Linux Virtual Console Limitation

The Linux text console (`tty1`-`tty6`) is different.

It uses console bitmap fonts (`psf` via `setfont` / console-setup), not the
same TTF/OTF font stack used by GUI terminals.

That means:

- you should **not** expect full Nerd Font support in the Linux virtual console
- tmux/SSH are irrelevant there because the console renderer itself is the
  limitation

Recommended approach:

- accept reduced glyph support on the Linux virtual console
- keep Nerd Font usage focused on GUI terminals and Windows Terminal

## Recommendation

Use `SauceCodePro Nerd Font Mono` in every GUI terminal you care about.

Do not try to force full Nerd Font parity into the Linux virtual console.

If a fully reproducible Linux desktop install becomes important later, vendor
the Nerd Font files under:

- `~/.dotfiles/_lib/sauce-code-pro-nerd-font`

and let `dotfiles-install` wire them into `~/.local/share/fonts`.
