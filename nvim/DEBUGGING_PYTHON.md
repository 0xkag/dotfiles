# Python Debugging Options

## Current Baseline

The current Neovim config uses a lightweight terminal-first Python debugging
flow:

- `SPC dd` / `,dd` debug the current file with `python -m ipdb`
- `SPC dt` / `,dt` debug the nearest pytest test with `pytest --trace`
- `SPC dT` / `,dT` debug the current test file
- `SPC dl` / `,dl` rerun the last debug command

These commands use the same Python interpreter that Neovim resolves through the
active `pyenv` / `.python-version` logic.

## Keep The Current Non-DAP Approach

Pros:

- small and reliable
- terminal-first and SSH-friendly
- fits the current pyenv-aware environment model cleanly
- fewer moving parts and less maintenance
- dependency reporting stays simple and explicit

Cons:

- no editor stack / locals / watch panes
- no gutter breakpoints yet
- stepping happens in the terminal debugger
- weaker attach / process-debugging workflows

## Add A Full DAP Stack

Typical direction:

- `mfussenegger/nvim-dap`
- `mfussenegger/nvim-dap-python`
- optional UI such as `rcarriga/nvim-dap-ui`

Pros:

- gutter breakpoints
- step / continue / restart controls inside Neovim
- stack, locals, watches, scopes, REPL, and frame navigation panes
- better repeated-debugging ergonomics
- easier path toward richer attach workflows

Cons:

- more moving parts and more failure modes
- more keybindings and UI complexity
- heavier maintenance cost than the terminal/ipdb flow
- adapter and interpreter resolution become another layer to keep aligned with
  pyenv and project environments

## Middle Ground

It should be possible to add lightweight gutter breakpoints without adopting
full DAP by storing breakpoints in Neovim and passing them to `pdb` at launch
time with `python -m pdb -c "break file.py:42"`.

That would provide:

- visible breakpoints in the gutter
- toggle / clear / list breakpoint commands
- Python launch flows that honor those breakpoints

It would not provide:

- stack / locals / watches panes
- in-editor stepping UI
- general-purpose adapter support across languages

## Recommendation

Stay on the current non-DAP baseline unless one of these becomes regular enough
to justify the extra moving parts:

- wanting stack / locals / watch panes inside Neovim
- needing persistent breakpoint-heavy workflows
- wanting attach / process debugging from the editor
- debugging often enough that terminal-only interaction becomes friction

If the main missing feature becomes stack / locals / watches alone, a DAP stack
is the clearest next step.
