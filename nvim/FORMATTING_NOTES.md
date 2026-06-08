# Formatting Notes

Background for the reflow/restyle layering in `lua/config/reflow.lua` and the
`gq` / `gQ` / `,=` mappings in `lua/config/keymaps.lua`. See also the Formatting
section in [README.md](./README.md:1).

## Two operations

There are two distinct jobs, kept separate on purpose:

- Reflow (structure-preserving) -- Vim's built-in formatter. Rewraps text to
  `textwidth` (78), honoring `formatoptions` and the buffer's comment leader
  (`#`, `//`, etc.). It never imposes a code style; it only re-wraps lines.
- Restyle (authoritative) -- conform / LSP (ruff, black, prettier, ...).
  Re-prints code from scratch in a canonical style.

`gq` reflows; `gQ` and `,=q` restyle. The default keeps `gq` doing exactly what
it did before, so existing muscle memory is unchanged.

## Keys

| Key | Modes | Action |
|---|---|---|
| `gq{motion}` / `gqq` | n, x | reflow per reflow_mode (default builtin) |
| `gQ{motion}` / `gQQ` | n, x | always restyle (formatter) |
| `,=q` (`<localleader>=q`) | n, x | restyle (same as gQ, in the ,= family) |
| `,=r` (`<localleader>=r`) | x | restyle selection (selection preserved) |
| `,=t` (`<localleader>=t`) | n | cycle reflow_mode |
| `,=b` (`<localleader>=b`) | n | restyle whole buffer (unchanged) |
| `,=o` (`<localleader>=o`) | n | organize imports (unchanged) |
| `<leader>cf` / `SPC c f` | n | format buffer via conform (unchanged) |

`gQ`/`gQQ` and `,=q` always restyle regardless of reflow_mode -- they are the
explicit deterministic sibling. `gq`/`gqq` reflow per reflow_mode.

## reflow_mode

A session-wide `reflow_mode` (`M.mode` in `lua/config/reflow.lua`) drives what
`gq` does. Cycle it with `,=t`. The cycle order is:

    builtin -> lsp -> smart -> conservative -> builtin

What `gq` does in each mode:

- `builtin` (default) -- built-in reflow. Today's behavior, unchanged.
- `lsp` -- conform / LSP restyle.
- `smart` -- treesitter-detected: comment / string nodes reflow; code restyles.
- `conservative` -- autopep8 for Python (fix-violations-only, preserves
  already-compliant code). Other filetypes restyle normally via conform. If
  autopep8 is unavailable, Python falls back to built-in reflow (one-time notify).

## Findings

1. `gq` had to be remapped. An attached LSP client sets
   `formatexpr=v:lua.vim.lsp.formatexpr()`, which reroutes `gq` through the
   server's range formatter -- that usually only re-indents and never reflows to
   `textwidth`, so `gq` becomes a silent no-op. Separately, nvim-treesitter sets
   `indentexpr`, which drops comment-continuation lines to column 0.
   `config.reflow.reflow_builtin` blanks both `formatexpr` and `indentexpr` for
   the duration of the format so `gq` behaves like plain Vim regardless of which
   LSP is attached.

2. `,=r` previously LOST the visual selection. An x-mode mapping defined as an
   ordinary Lua function exits visual mode the instant it fires (standard Vim
   semantics), and the `'<` / `'>` marks are only updated AFTER leaving visual
   mode -- so they pointed at the previous selection. Fix: read the live
   selection via `getpos("v")` / `getpos(".")` (`config.reflow.selection_range`,
   which returns rows 1-indexed and columns 0-indexed to match conform's range)
   and reselect afterward (see finding 6 for which marks).

3. There is NO "preserve my code style" restyle. ruff and black parse to an AST
   and re-print from scratch in one canonical, non-configurable style -- there
   is no "fix only what is broken" flag. The conservative option is autopep8,
   which runs pycodestyle and edits only the violating lines, leaving compliant
   code untouched. It is opt-in via `reflow_mode = "conservative"` and is
   Python-only; other filetypes just restyle normally via conform.

4. `gQ` replaces stock Vim's Ex-mode entry. Ex mode is rarely used
   interactively and is still reachable via `Q`.

5. smart mode forces a treesitter parse before querying the node. An unparsed
   buffer (e.g. one just loaded) returns nil from `get_node`, which would
   otherwise make smart mode misclassify everything as code and always restyle.

6. The visual maps reselect by two different strategies, because a reflow can
   change the line count (a 2-line bullet that wraps to 3, or three short lines
   that join to one). `config.reflow.reflow_builtin` returns `true` to signal it
   reflowed synchronously, so `dispatch_range` returns `true` on the reflow path
   and a falsy value on the restyle path. The visual `gq` / `gQ` / `,=q` maps
   then reselect:
   - reflow -> ``normal! `[V`]`` -- the `'[` / `']` change marks span the actual
     reflowed extent, so the selection grows or shrinks to match the new wrap.
   - restyle -> `gv` -- conform formats asynchronously, so the edit has not
     landed when the map returns; `'[` / `']` are not yet valid. `gv` restores
     the original selection as a best effort. (`,=r` is always restyle, so it
     always uses `gv`.)
