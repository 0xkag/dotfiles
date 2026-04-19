# Picker And FZF Notes

## Current Baseline

The current Neovim setup already has a coherent picker and discovery stack:

- Telescope is the main fuzzy finder and picker UI
- `which-key` provides transient leader and localleader discovery
- Neo-tree provides tree/sidebar browsing
- Oil provides dired-style directory editing

That means there is no current functional gap that requires fzf integration.

## Why FZF Is Not Required Right Now

Telescope already covers the high-value workflows in this config:

- file search
- project grep
- buffer switching
- command discovery
- keymap discovery
- help/documentation lookup
- LSP and diagnostics pickers

For this setup, adding fzf would be a preference choice rather than a missing
capability fix.

## Option 1: Keep Telescope Only

Pros:

- smallest maintenance surface
- already integrated throughout the current config
- no extra plugin stack or build step
- consistent UI across files, grep, commands, keymaps, help, and LSP pickers

Cons:

- does not match the terminal fzf experience exactly
- does not use fzf query syntax or ranking behavior

## Option 2: Add `telescope-fzf-native.nvim`

This keeps Telescope as the user-facing picker but swaps in an fzf-style sorter.

Pros:

- lowest-risk fzf integration
- preserves existing Telescope mappings and workflows
- likely the right first experiment if faster or more familiar matching is the
  only goal

Cons:

- still feels like Telescope, not full fzf
- adds a native build step

## Option 3: Add `fzf-lua`

This is the strongest option if the real goal is "make Neovim feel like fzf".

Pros:

- modern Neovim-native fzf-first workflow
- closer to terminal fzf feel than Telescope
- a better fit than legacy `fzf.vim` for a Lua-based Neovim config

Cons:

- creates overlapping picker stacks with Telescope
- would require either coexistence rules or a migration away from Telescope
- more configuration churn for limited immediate benefit

## Option 4: Add `fzf.vim`

This remains viable, but it is not the recommended direction for this config.

Pros:

- classic Vim/fzf integration
- familiar for long-time Vim users already invested in it

Cons:

- not the best fit for a Lua-first Neovim config
- less attractive than `fzf-lua` if starting fresh

## Recommendation

Keep the current Telescope-based setup unless there is a specific desire for
fzf's exact matching behavior or interface.

If fzf integration is revisited later, the decision order should be:

1. Try `telescope-fzf-native.nvim` first.
2. Move to `fzf-lua` only if a true fzf-first experience becomes important.
3. Skip `fzf.vim` unless there is a strong reason to prefer the classic Vim
   plugin path.

## Sources

- Telescope:
  https://github.com/nvim-telescope/telescope.nvim
- Telescope fzf-native sorter:
  https://github.com/nvim-telescope/telescope-fzf-native.nvim
- `fzf-lua`:
  https://github.com/ibhagwan/fzf-lua
- `fzf.vim`:
  https://github.com/junegunn/fzf.vim
