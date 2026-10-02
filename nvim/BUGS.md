# Upstream Bugs To File

Bug reports drafted from the terraform-files-lockup investigation (see
[DEBUGGING_NVIM.md](./DEBUGGING_NVIM.md:1) for how it was diagnosed, and the
"LSP performance in large repos" section of [README.md](./README.md:1) for the
local workaround that shipped). Not yet filed — drafted here for later
consideration.

## Summary

A single malformed LSP semantic token hangs Neovim's main thread. It is an
upstream bug on **both** sides:

- **terraform-ls** emits a semantic token whose `deltaStartChar` is a small
  negative delta wrapped to an unsigned 32-bit int (`4294967253` ==
  `2^32 - 43`) — an invalid offset it should never send.
- **Neovim** does not bound its semantic-token range-extension loop, so that
  out-of-range value spins the loop billions of times on the main thread and
  wedges the UI (unresponsive even to `SIGTERM`).

The local config carries a client-side clamp
(`lua/config/lsp_semantic_guard.lua`) as a workaround, but the fix belongs
upstream on both projects.

## Reports

- [BUG_REPORT_1.md](./BUG_REPORT_1.md:1) — Neovim: `vim.lsp.semantic_tokens`
  hangs on out-of-range token delta/length. Filled to the neovim/neovim "Bug
  report" form. Includes a self-contained `nvim --clean -u minimal.lua` repro
  (in-process fake server, verified to hang on the bad value and return
  instantly on a valid one).
- [BUG_REPORT_2.md](./BUG_REPORT_2.md:1) — terraform-ls: emits a semantic token
  with an out-of-range `deltaStart`. Filled to the hashicorp/terraform-ls "Bug
  report" form (a "Performance" form also exists, but this is a correctness bug
  in the encoded value, so "Bug report" fits better).
- [BUG_REPORT_3.md](./BUG_REPORT_3.md:1) — Neovim: treesitter highlighter
  reuses pre-edit tree objects while an async parse is pending, so an edit
  that shortens the buffer (`J`) dies with `treesitter.lua:212: Index out of
  bounds` in a text predicate. Filled to the neovim/neovim "Bug report" form.
  Includes a self-contained `nvim --clean -c 'luafile repro.lua'` repro that
  stalls the timed parse step to force the race. Local workaround shipped in
  `lua/config/options.lua` (`vim.g._ts_force_sync_parsing = true`).

## Things to flag before filing

- **The terraform-ls repro is workspace-level, not yet a single minimal `.tf`.**
  Their form requests a config; it is marked honestly as not-yet-minimized. The
  high-value next step is identifying *which* construct produces the bad token
  — a probe that logs the byte offset/line of the offending token would let you
  point them at the exact source span. Worth doing for a stronger report.
- **Neither tracker has been searched for duplicates.** Check before filing:
  Neovim for `semantic_tokens hang` / `str_utfindex`; terraform-ls for
  `semantic tokens deltaStart` / `4294967253`.
- **Report 3 has a likely duplicate.** neovim/neovim#38303 ("Treesitter
  highlighter, out of bounds checks", 0.11.6, same `get_node_text` path, open
  and tagged needs-reproduction) is probably the same race seen from the
  `on_line` side. Comment there with the repro rather than opening a new
  issue unless a maintainer asks for one.
- The Neovim repro is solid and standalone; the terraform-ls one currently
  leans on the wire capture (the `data`-array dump) rather than a from-scratch
  reproduction. Both are honest about their state.
