# Bug Report 3 — Neovim

File at: https://github.com/neovim/neovim/issues/new (use the "Bug report" form)
Check neovim/neovim#38303 first: same `get_node_text` path, 0.11.6, open and
tagged needs-reproduction; this is very likely the same race and the repro
below may belong there as a comment instead.

**Title:** treesitter highlighter reuses pre-edit tree objects while an async
parse is pending; an edit that shortens the buffer then fails with
`treesitter.lua:212: Index out of bounds` in a text predicate

## Problem

Joining a backslash-continued two-line command with `J` in a treesitter
highlighted buffer intermittently raised:

```
Decoration provider "range" (ns=nvim.treesitter.highlighter): Lua:
.../runtime/lua/vim/treesitter.lua:212: Index out of bounds
stack traceback:
  [C]: in function 'nvim_buf_get_text'
  .../runtime/lua/vim/treesitter.lua:212: in function 'get_node_text'
  .../runtime/lua/vim/treesitter/query.lua:554: in function 'handler'
  .../runtime/lua/vim/treesitter/query.lua:843: in function '_match_predicates'
  .../runtime/lua/vim/treesitter/query.lua:981: in function 'iter'
  .../runtime/lua/vim/treesitter/highlighter.lua:402: in function 'fn'
  .../runtime/lua/vim/treesitter/highlighter.lua:245: in function 'for_each_highlight_state'
  .../runtime/lua/vim/treesitter/highlighter.lua:361: in function <.../highlighter.lua:335>
```

`query.lua:554` is the `#any-of?` predicate handler. It is reading the text of
a node on a row that no longer exists. Four pieces of the runtime combine to
get there (line numbers are 0.12.2):

1. **`TSTree:edit()` returns a copy.** `tree_edit` in
   `src/nvim/lua/treesitter.c` does `ts_tree_copy` + `ts_tree_edit` +
   `push_tree`, so the tree object it was called on is never edited.
   `LanguageTree:_edit` (`languagetree.lua:1161`) stores the copy with
   `self._trees[i] = tree:edit(...)`; any other reference to the old object
   keeps the pre-edit node positions.

2. **The highlighter caches those objects.**
   `TSHighlighter:prepare_highlight_states` stores `tstree` (the
   `LanguageTree` tree object at that moment) in `self._highlight_states`.

3. **A pending async parse makes it reuse them.** `TSHighlighter._on_start`
   (`highlighter.lua:557`) sets `highlighter.parsing = true` when
   `tree:parse(ranges, cb)` returns `nil`, which `LanguageTree:_async_parse`
   does whenever its first `step()` yields, i.e. when the parse plus injection
   work exceeds `default_parse_timeout_ns` (3 ms; `_subtract_time` yields the
   coroutine once the budget hits zero). `TSHighlighter._on_win`
   (`highlighter.lua:539`) then skips `prepare_highlight_states` and only
   resets the iterators on the cached states, so `on_range_impl` iterates the
   **pre-edit** trees. Highlighting a stale frame is the intended degrade, but
   the trees it uses are not the edited ones; they are the objects from before
   `_edit` ran.

4. **Text predicates run before any bounds check.** `on_range_impl`
   (`highlighter.lua:335`) builds `iter_captures(root_node, bufnr,
   range_start_row, root_range[3], ...)` from the stale root, so the query
   cursor covers rows past the end of the buffer. `Query:iter_captures`'s
   `iter` (`query.lua:959`) calls `_match_predicates` before its end-of-range
   check, and `#any-of?` / `#eq?` / `#match?` / `#lua-match?` all call
   `get_node_text` → `nvim_buf_get_text`, which rejects the row with
   `Index out of bounds`. The extmark side of the same loop already guards
   against this exact state (the `#35814` workaround checks
   `nvim_buf_line_count` before `nvim_buf_set_extmark`); the predicate side
   does not.

Only an edit that makes the buffer (or a line) shorter can point the stale
tree outside the buffer, which is why `J`, `dd`, `x` at line end and undo of
an insert are the triggers. The error is transient: the pending parse
finishes, `parsing` resets, and the next redraw is correct.

It is rare in practice because the redraw-time parse of a two-line buffer
takes 0.05 to 0.25 ms here against the 3 ms budget; it needs a GC pause, a
page fault in a large parser (the zsh grammar's scanner is 4.6 MB), or CPU
contention right after startup to overrun. The repro below forces the overrun
by stalling `LanguageTree._add_injections`, which is the step
`_subtract_time` times, for 4 ms.

Observed with the `zsh` and `bash` grammars from nvim-treesitter and with the
bundled `lua` parser; independent of user config (reproduces under
`nvim --clean`).

## Steps to reproduce

Save as `repro.lua`. Uses only the bundled `lua` parser and a one-pattern
highlights query so the first capture on the stale row has to read node text.

```lua
-- Reproduce: stale treesitter highlight state after an edit that shortens the
-- buffer, when the redraw-time parse does not finish inside its 3 ms budget.
--
--   nvim --clean --headless -c 'luafile repro.lua'   (prints :messages, quits)
--   nvim --clean -c 'luafile repro.lua'              (shows the error on screen)
vim.schedule(function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'local a = 1', '    self.b = 2' })
  vim.api.nvim_win_set_buf(0, buf)

  -- One pattern with a text predicate, so the first capture on the stale
  -- second line has to read node text.
  vim.treesitter.query.set('lua', 'highlights',
    '((identifier) @variable.builtin (#eq? @variable.builtin "self"))')
  vim.treesitter.start(buf, 'lua')
  vim.cmd.redraw() -- first highlight pass caches the two-line tree objects

  -- Simulate the redraw-time parse overrunning its 3 ms budget: _add_injections
  -- is timed by LanguageTree:_subtract_time, so a 4 ms stall makes parse()
  -- yield and return nil, which sets highlighter.parsing = true.
  local LanguageTree = require('vim.treesitter.languagetree')
  local add_injections = LanguageTree._add_injections
  LanguageTree._add_injections = function(self, ...)
    local t = vim.uv.hrtime()
    while vim.uv.hrtime() - t < 4e6 do
    end
    return add_injections(self, ...)
  end

  vim.cmd('normal! ggJ') -- buffer is now one line; the cached tree still has two
  vim.cmd.redraw()
  LanguageTree._add_injections = add_injections

  if #vim.api.nvim_list_uis() == 0 then
    vim.wait(300, function() return false end)
    io.stdout:write(vim.api.nvim_exec2('messages', { output = true }).output, '\n')
    vim.cmd.qall({ bang = true })
  end
end)
```

Run:

```
nvim --clean --headless -c 'luafile repro.lua'
```

Output (trimmed; `query.lua:395` is the `#eq?` handler here, `554` is
`#any-of?` in the real-world trace above):

```
Decoration provider "range" (ns=nvim.treesitter.highlighter):
Lua: .../runtime/lua/vim/treesitter.lua:212: Index out of bounds
stack traceback:
  [C]: in function 'nvim_buf_get_text'
  .../runtime/lua/vim/treesitter.lua:212: in function 'get_node_text'
  .../runtime/lua/vim/treesitter/query.lua:395: in function 'handler'
  .../runtime/lua/vim/treesitter/query.lua:843: in function '_match_predicates'
  .../runtime/lua/vim/treesitter/query.lua:981: in function 'iter'
  .../runtime/lua/vim/treesitter/highlighter.lua:402: in function 'fn'
  .../runtime/lua/vim/treesitter/highlighter.lua:245: in function 'for_each_highlight_state'
  .../runtime/lua/vim/treesitter/highlighter.lua:361: in function <.../highlighter.lua:335>
  [C]: in function 'redraw'
```

Control: change `4e6` to `0` (no stall) and the same script prints nothing.
Without `--headless` the error shows in the message area of the open editor.

The real-world path needs no monkeypatching, only a slow moment: open a
two-line shell command in a `bash`/`zsh` highlighted buffer via zsh's
`edit-command-line` (`nvim -c "normal! <N>go" -- /tmp/zshecl<pid>`) and press
`J` on line 1 while the machine is busy.

## Expected behavior

A frame highlighted from a not-yet-reparsed tree should degrade to stale
colours, never to an error. Any of these would do:

- when `parsing` is true, `_on_win` should refresh `state.tstree` from the
  current `self.tree:trees()` (the edited copies) instead of the objects
  captured before the edit, so node positions match the buffer;
- or `TSTree:edit()` should edit in place (or `LanguageTree:_edit` should
  notify holders of the old object), so cached references cannot go stale;
- or the predicate path should get the same bounds guard the extmark path has,
  i.e. skip a match whose captured node lies outside the buffer rather than
  calling `nvim_buf_get_text` on it.

Workaround in the meantime: `vim.g._ts_force_sync_parsing = true` makes
`LanguageTree:parse` run to completion, so `parsing` can never be true and the
cached states are always rebuilt from the current trees.

## Nvim version (nvim -v)

`NVIM v0.12.2` (Release, LuaJIT 2.1.1774638290)

## Vim (not Nvim) behaves the same?

N/A — treesitter highlighting is a Neovim runtime feature with no Vim
equivalent.

## Operating system/version

Amazon Linux 2 (Linux 5.15.213 x86_64)

## Terminal name/version

Reproducible headless (`nvim --clean --headless -c 'luafile repro.lua'`);
terminal-independent.

## $TERM environment variable

`xterm-256color` (not relevant — reproduces headless)

## Installation

Nix (`neovim-unwrapped` 0.12.2) via flox
