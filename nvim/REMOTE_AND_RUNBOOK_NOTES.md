# Remote Editing And Literal Runbook Options

## Current Baseline

- Local directory editing is handled by `oil.nvim`.
- Tree/sidebar browsing is handled by Neo-tree.
- Builtin `netrw` is intentionally disabled in
  [init.lua](./init.lua:1) so it does not compete with
  Oil and Neo-tree for directory buffers.
- Org support currently comes from `nvim-orgmode/orgmode` with agenda/capture
  basics and Org file editing.

## Literal Runbooks / Org Babel

### Current State

The current Org setup is not a full Org Babel replacement.

What is already available:

- Org editing through `nvim-orgmode`
- basic tangling support
- basic `:noweb` support
- Org src-block editing through Orgmode's edit-special flow

What is not currently available:

- full native Org Babel execution semantics
- mature multi-language code-block execution inside Neovim Org buffers
- a clean 1:1 replacement for Emacs Org Babel sessions and result handling

### Option 1: Stay On The Current Orgmode Baseline

Use Org files as literate notes/runbooks, but keep execution outside Org:

- tangle from Org when needed
- run commands manually in terminals
- use normal editor/test/debug tooling for execution

Pros:

- lowest complexity
- fully aligned with the current Neovim setup
- no extra runtime dependencies

Cons:

- not a true Org Babel workflow
- no inline block execution model

### Option 2: Add `orgmode-babel.nvim`

`mrshmllow/orgmode-babel.nvim` adds `:OrgExecute` and `:OrgTangle`, but it is
experimental and uses Emacs under the hood for compatibility.

Pros:

- closest known Org-Babel-style execution option in Neovim
- keeps Org buffers as the primary runbook format

Cons:

- explicitly experimental
- not a fully native Neovim solution
- depends on a working `emacs` binary
- adds another integration layer to maintain

### Option 3: Use Non-Org Execution Tools

Possible examples:

- REPL-driven execution such as `iron.nvim`
- notebook/kernel-driven execution such as `molten.nvim`

Pros:

- often more mature for code execution than Org-specific Neovim tooling
- better fit if the real need is "run code blocks interactively" rather than
  "preserve Org Babel semantics"

Cons:

- not an Org-Babel replacement
- does not preserve the Emacs Org runbook model

### Recommendation

Leave this alone unless literal runbooks become a real day-to-day need.

If that happens, the decision order should be:

1. Confirm whether tangling-only is enough.
2. If execution is required, decide whether depending on Emacs is acceptable.
3. Only add `orgmode-babel.nvim` if the answer is yes.

## Remote Editing / TRAMP-Like Workflows

### Current State

There is no TRAMP-equivalent workflow configured right now.

Because `netrw` is disabled, builtin `scp://` / `ftp://` editing is also
currently disabled.

### Option 1: Use Oil's SSH Adapter

Oil supports remote paths in the form:

- `oil-ssh://user@host/path`

This is the cleanest future direction if the current local file-browser setup
should remain intact.

Pros:

- fits the current Oil-based directory editing workflow
- keeps local browsing consistent
- does not require re-enabling `netrw`
- supports remote browsing and remote file editing within the same directory
  editor already in use

Cons:

- still not TRAMP in the Emacs sense
- depends on remote shell tooling being available
- less battle-tested historically than builtin netrw

### Option 2: Re-enable `netrw` For Remote Paths

Neovim's builtin `netrw` supports remote URLs such as:

- `scp://user@host/path`
- `ftp://host/path`

Pros:

- builtin
- closest direct analogue to classic Vim remote editing
- no extra plugin required

Cons:

- conflicts with the intentional Oil/Neo-tree split unless handled carefully
- can create confusing directory-opening behavior
- would need a deliberate design so local directory browsing still prefers Oil

### Option 3: Add A Remote Workspace Plugin

Two notable directions:

- `remote-sshfs.nvim` for SSHFS-backed remote workspaces
- `remote-nvim.nvim` for VS Code Remote-SSH-style remote Neovim sessions

Pros:

- better fit for full remote development than simple remote file editing
- can be stronger when search, indexing, or remote tool execution matter

Cons:

- heavier than simple remote file access
- more dependencies and operational complexity
- `remote-nvim.nvim` explicitly describes itself as not yet mature

### Recommendation

Leave remote editing unconfigured until there is a concrete need.

If remote editing becomes important, the decision order should be:

1. Try Oil SSH first, because it matches the current config design.
2. Revisit `netrw` only if builtin `scp://` workflows are specifically wanted.
3. Move to a remote-workspace plugin only if remote development, not just
   remote file editing, becomes the real requirement.

## Sources

- `nvim-orgmode` configuration and tangling docs:
  https://nvim-orgmode.github.io/configuration
- `orgmode-babel.nvim`:
  https://github.com/mrshmllow/orgmode-babel.nvim
- Neovim `netrw` docs:
  https://neovim.io/doc/user/pi_netrw
- `oil.nvim` SSH adapter docs:
  https://github.com/stevearc/oil.nvim
- `remote-sshfs.nvim`:
  https://github.com/nosduco/remote-sshfs.nvim
- `remote-nvim.nvim`:
  https://github.com/amitds1997/remote-nvim.nvim
