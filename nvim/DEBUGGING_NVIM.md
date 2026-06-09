# Debugging Neovim Performance and Hangs

Reusable recipes for diagnosing Neovim main-thread hangs and CPU spikes,
written up from a real case: opening ~88 terraform files from a large monorepo
pinned a core at ~96% indefinitely while a single file was fine. The eventual
cause was a malformed LSP semantic token (see the "LSP performance in large
repos" section of README.md), but the *path* to finding it is the reusable
part. The first two hypotheses were wrong; the profiler is what settled it.

## Principle: read the symptom before guessing

A hang has a measurable shape. Read it before changing anything.

- `ps -eo pid,ppid,stat,pcpu,pmem,etimes,comm,args | grep -E 'nvim|<lsp>'`
  - `stat` of `R`/`Rl` = on-CPU (a busy loop). `S`/`Sl` = sleeping (waiting on
    IO or a child). `D` = uninterruptible IO.
  - If **nvim itself** is `R` at ~100% while its language-server child is `S`
    with *declining* CPU, the work is on Neovim's own main thread (Lua/C), not
    the server. That single observation rules out "the server is slow" and
    points at config/runtime code.
- A process that **ignores SIGTERM** (does not die on `timeout 40 ...`) is
  almost always in a tight synchronous loop that never yields to the event
  loop. Use `timeout -s TERM -k 5 <secs>` so a hung nvim gets SIGKILL after the
  grace period and does not leak (these strays otherwise need `kill -9`).

## Reproduce headless, off the main coroutine

Run the real scenario without the UI so it is scriptable and killable:

```sh
cd <repo>
timeout -s TERM -k 5 40 nvim --headless -n <the exact file globs> \
  -S /tmp/probe.lua 2>/tmp/err.log
echo "exit=$?"   # 0 = clean quit, 124/137 = timed out/killed (still hung)
```

Notes that bit us:
- `--headless` does **not** fire `VeryLazy`/`UIEnter`, so lazy-loaded plugins
  (LSP via `event = "VeryLazy"`) may never load. Force them explicitly inside
  the probe: `require("lazy").load({ plugins = { "nvim-lspconfig" } })`, then
  `:edit` the first file so a server actually attaches.
- Have the probe **write its findings to a file** and `qa!`. If nvim hangs, a
  `vim.defer_fn` callback may never run (the main loop is starved) -- so also
  flush incrementally where possible (see profiler below).
- Prefer `-S /tmp/probe.lua` over inline `-c 'lua ...'`. Inline Lua pasted into
  a terminal gets line-wrapped and silently mangled; a sourced file does not.
  (We wasted a round on a mangled inline probe that "proved" low CPU only
  because the LSP never loaded.)

## Falsify a hypothesis by neutering the suspect

Before building a fix for a suspected subsystem, prove it is the cause by
disabling *just that subsystem* at the source and seeing if the hang stops.
Monkey-patch the runtime function in a probe, log calls, and skip the original:

```lua
-- Did the LSP file-watcher cause it? Neuter registration, log, do not watch.
local wf = require("vim.lsp._watchfiles")
wf.register = function(reg, client_id)
  vim.fn.writefile({ "register called for " .. client_id }, "/tmp/watch.log")
  -- intentionally NOT calling the original: no watch is ever started
end
```

In our case this was decisive *against* the hypothesis: with `register`
neutered the hang persisted, and the log showed `register` was never even
called. The file-watcher was innocent. Disproving a theory cheaply is as
valuable as proving one.

## Profile the main thread with jit.profile

When you do not know *where* the loop is, sample it. LuaJIT's `jit.profile`
interrupts the VM on a timer and dumps the stack even inside a tight Lua loop,
so it catches hangs that no `print`/`defer_fn` can reach. Flush counts to disk
periodically so a SIGKILL still leaves data.

```lua
local profile = require("jit.profile")
local counts, total = {}, 0
local function flush()
  local arr = {}
  for stack, n in pairs(counts) do arr[#arr + 1] = { stack = stack, n = n } end
  table.sort(arr, function(a, b) return a.n > b.n end)
  local f = io.open("/tmp/prof.out", "w")
  f:write("total=" .. total .. "\n\n")
  for i = 1, math.min(25, #arr) do f:write(arr[i].n .. "\t" .. arr[i].stack .. "\n") end
  f:close()
end
profile.start("li1", function(thread, samples)
  local stack = profile.dumpstack(thread, "pl\n  ", 8)  -- "p"=path:line, "l"=line; depth 8
  counts[stack] = (counts[stack] or 0) + samples
  total = total + samples
  if total % 200 < samples then flush() end             -- survive SIGKILL
end)
-- ... load plugins, open the file, let it hang; flush() also on clean exit ...
```

The top stack line is the culprit. Ours was ~96% in
`runtime/lua/vim/lsp/semantic_tokens.lua:144-148` -- a `while` loop -- which is
how we found it at all. `"li1"` = sample by line, ~1ms interval; raise the
interval (e.g. `"li5"`) for cheaper sampling.

## Inspect the data feeding a hot loop

Once you know the loop, look at the values driving it instead of guessing which
field is bad (we guessed wrong once -- clamped `length` when `deltaStart` was
the corrupt field). Wrap the function that receives the data, log
min/max/worst-tuple, write to disk, and do **not** call the original so you do
not re-enter the hang:

```lua
local st = require("vim.lsp.semantic_tokens")
st.__STHighlighter.process_response = function(self, response, ...)
  local data = response and response.data           -- flat 5-int tuples
  -- ... scan for max of each field, dump the worst tuple ...
  vim.fn.writefile(out, "/tmp/tokdump.out")
  vim.schedule(function() vim.cmd("qa!") end)        -- stop; never call original
end
```

This is what exposed the unsigned-32-bit wraparound: a `deltaStart` of
`4294967253` (`2^32 - 43`, i.e. a small negative delta the server should not
have sent). A value near `2^32` or `2^31` in an integer field is the
fingerprint of a signed/unsigned encoding bug upstream.

## Patching runtime internals from config (last resort)

When the bug is in a `local function` you cannot reach, look for an exported
seam. `vim.lsp.semantic_tokens` exposes `M.__STHighlighter` (the underscore
signals "internal, but reachable") -- we wrapped its `process_response` method.
Guidelines that kept this safe:
- Make `apply()` **idempotent** and a **no-op if the shape changed**
  (`type(x) ~= "function"` guards), so a Neovim upgrade degrades gracefully
  instead of erroring.
- Keep the actual transform a **pure function** and unit-test it headless (see
  `test/lsp_semantic_guard_spec.lua`); only the thin wrapper touches runtime
  internals.
- Prefer the **least-damaging clamp** over disabling a feature: bounding the
  malformed value left semantic highlighting fully working, whereas disabling
  semantic tokens would have lost real functionality.

## Tests run headless

All specs are self-contained and run via `test/run.sh` (each does
`nvim --headless -u NONE -l <spec>`, prints `ok`/`FAIL`, `cquit 1` on failure).
Fake `vim.fn.has`/`vim.fn.executable` to exercise platform branches; build real
scratch buffers with `nvim_create_buf` + `nvim_buf_set_lines` to test
buffer-dependent helpers.
