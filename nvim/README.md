# Neovim Migration Notes

This configuration is a Spacemacs-style Neovim setup centered on modal editing,
leader-key discovery, LSP, search, git, tests, terminals, and writing support.

## Core keys

- `SPC` is the main leader key
- `,` is the local leader key
- `fd` exits insert mode
- `Y` yanks to end of line
- `gl` and `gL` align text

## Main leader groups

- `SPC b` buffers
- `SPC c` code and LSP
- `SPC e` edit and multiple cursors
- `SPC f` files
- `SPC g` git
- `SPC o` open, org, outline, and terminals
- `SPC p` project
- `SPC q` quit and sessions
- `SPC r` tests
- `SPC s` search
- `SPC t` toggles
- `SPC w` windows
- `SPC y` clipboard

## Useful commands

- `:Mason` manage language servers
- `:ConformInfo` inspect formatter setup
- `:Neogit` open the git UI
- `:Org help` view orgmode help
- `:TSInstall lua python markdown markdown_inline org http` install parsers you want
- `:checkhealth` inspect Neovim health

## Org defaults

- Agenda files: `~/wc/personal/personal/*.org`
- Default notes file: `~/wc/personal/personal/todo.org`
- Global org actions: `SPC o a` for agenda, `SPC o c` for capture

## HTTP files

- Open a `.http` file and use localleader mappings
- `,r` run request under cursor
- `,a` run all requests in the current buffer
- `,l` replay the last request
- `,o` open the result pane
- `,i` inspect the parsed request
- `,s` show request stats
