# FreeBSD Neovim Notes

## Summary

Do not install Neovim through `mise` on FreeBSD.

The current `mise` Neovim tool uses `vfox:mise-plugins/vfox-neovim`, and that
plugin rejects FreeBSD during preinstall with:

```text
Unsupported OS: freebsd
```

That is a plugin limitation, not a problem with Neovim itself.

## Current Dotfiles Policy

[mise/config.toml](/home/kag/.dotfiles/mise/config.toml:1) intentionally
restricts the managed Neovim tool to operating systems supported by the mise
plugin:

```toml
neovim = { version = "0.12.1", os = ["linux", "macos", "windows"] }
```

On FreeBSD, install Neovim with the system package manager instead:

```sh
sudo pkg install neovim
```

If the package repository is too old and the latest port is required:

```sh
cd /usr/ports/editors/neovim
sudo make install clean
```

The dotfiles installer still initializes the Neovim config everywhere by
creating:

```text
~/.config/nvim -> ../.dotfiles/nvim
```

On FreeBSD, the installer also prints the `pkg install neovim` hint.

## Rationale

FreeBSD already carries Neovim as `editors/neovim`, and Neovim's own install
documentation points FreeBSD users at `pkg` or the ports tree.

Using FreeBSD packages also avoids carrying a local workaround for the mise
plugin's unsupported OS path.

## Sources

- mise OS-specific tool configuration:
  https://mise.jdx.dev/dev-tools/
- Neovim FreeBSD install docs:
  https://neovim.io/doc/install/
- FreshPorts `editors/neovim`:
  https://www.freshports.org/editors/neovim/
