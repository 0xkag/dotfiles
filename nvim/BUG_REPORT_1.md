# Bug Report 1 — Neovim

File at: https://github.com/neovim/neovim/issues/new (use the "Bug report" form)

**Title:** `vim.lsp.semantic_tokens` hangs main thread on out-of-range token
delta/length (no bounds on range-extension loop)

## Problem

`vim.lsp.semantic_tokens` can lock up the editor indefinitely (one CPU core at
~100%, unresponsive even to `SIGTERM`) when a language server sends a semantic
token whose `deltaStartChar` or `length` is out of range — e.g. a small
negative delta encoded as an unsigned 32-bit integer (`4294967253` ==
`2^32 - 43`).

In `runtime/lua/vim/lsp/semantic_tokens.lua`, `tokens_to_ranges()` computes
`end_char = start_char + length` and then extends the token across lines:

```lua
local new_end_char = end_char - vim.str_utfindex(buf_line, encoding) - eol_offset
while new_end_char > 0 do
  end_char = new_end_char
  end_line = end_line + 1
  buf_line = lines[end_line + 1] or ''
  new_end_char = new_end_char - vim.str_utfindex(buf_line, encoding) - eol_offset
end
```

Once `end_line` passes the end of the buffer, `buf_line` is `''`, so
`vim.str_utfindex('')` is `0` and `new_end_char` only decreases by `eol_offset`
(1) per iteration. With an astronomical `start_char`/`end_char` the loop runs
billions of iterations on the main thread. There is no clamp of the incoming
token values to the buffer geometry, and no upper bound on the loop, so a
single malformed token wedges the UI. (The LSP spec requires a semantic token
to be contained within a single line, so any in-range token resolves the loop
in one or two iterations; only out-of-range values trigger this.)

Found via `jit.profile`, which showed ~96% of main-thread samples at
`semantic_tokens.lua:144-148`.

## Steps to reproduce

Minimal repro using an in-process server (no plugins, no external LSP). Save as
`minimal.lua` and run `nvim --clean -u minimal.lua`:

```lua
local function server(dispatchers)
  local closing = false
  local srv = {}
  function srv.request(method, params, callback)
    if method == "initialize" then
      callback(nil, { capabilities = { semanticTokensProvider = {
        full = true,
        legend = { tokenTypes = { "variable" }, tokenModifiers = {} },
      } } })
    elseif method == "textDocument/semanticTokens/full" then
      -- {deltaLine, deltaStartChar, length, tokenType, tokenModifiers}
      -- 4294967253 == 2^32 - 43, a negative delta wrapped to uint32
      callback(nil, { data = { 0, 4294967253, 3, 0, 0 } })
    elseif method == "shutdown" then
      callback(nil, nil)
    end
    return true, 1
  end
  function srv.notify() return true end
  function srv.is_closing() return closing end
  function srv.terminate() closing = true end
  return srv
end

local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "alpha beta gamma", "second line" })
vim.lsp.start({ name = "fake-st", cmd = server })
vim.defer_fn(function() vim.cmd("redraw!") end, 200)
```

Neovim hangs immediately at one core / 100% CPU. Replacing `4294967253` with a
valid `2` (or any in-range value) returns instantly — confirming the trigger is
the out-of-range delta, not the harness.

## Expected behavior

A malformed/out-of-range semantic token should not be able to hang the editor.
Neovim should clamp the token's `deltaStartChar`/`length` to the buffer
geometry (a token cannot span beyond a line per the LSP spec), or otherwise
bound the range-extension loop, and ignore/skip the offending token rather than
spin.

## Nvim version (nvim -v)

`NVIM v0.12.2` (Release, LuaJIT 2.1.1774638290)

## Vim (not Nvim) behaves the same?

N/A — `vim.lsp.semantic_tokens` is a Neovim runtime feature with no Vim
equivalent.

## Operating system/version

Amazon Linux 2 (Linux 5.15.198 x86_64)

## Terminal name/version

Reproducible headless (`nvim --headless --clean -u minimal.lua` → killed by
`timeout`); terminal-independent.

## $TERM environment variable

`xterm-256color` (not relevant — reproduces headless)

## Installation

Nix (`neovim-unwrapped` 0.12.2)
