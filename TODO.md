- binaries: Remove more `_lib` submodules in favor of just installing with
  mise (started this already)
- binaries: Capture standard set of pipx / mise installed things
- binaries: Pyenv 3.12.11 is used in pipx/install but nothing makes sure
  3.12.11 is installed before that runs; this is a bootstrapping problem
- binaries: poetry and ruff are installed via pipx and need to be automated
- binaries: Rationalize use of mise vs. system package manager
- binaries: One package list for every platform, replacing the per-platform
  lists in `_reqs/` (ubuntu, macos-brew, freebsd, openbsd, rockylinux8,
  flox-al2, python): each tool once, with its name and install method per
  platform (apt/brew/pkg/pkg_add/yum/flox/mise/pipx/snap/built from source),
  or none; needs a file format (and probably an installer reading it);
  recent additions to seed it: chafa and vifm (apt; flox on AL2), ghostty
  (snap), yazi/hurl/tree-sitter (mise), ansible-lint (pipx)
- binaries: Support for NFS homedir mounted on multiple architectures (amd64
  and arm64); this is a problem for things like ~/.local, pyenv, pipx, and
  mise
- docs: Shell toolchain productivity backlog in
  _docs/shell-toolchain-recommendations.md (ssh/fzf/git/zsh/tmux/nvim);
  update item statuses as work lands
- editor: vim git commit message fill column at 75
- editor: Track nvim-treesitter-locals
  (https://github.com/nvim-treesitter/nvim-treesitter-locals) as a future
  pure-treesitter alternative for in-buffer local rename; it's a stub as
  of late 2025
- editor: Inline images in nvim (snacks.image: PNG/JPG, Markdown images,
  Mermaid via mmdc, LaTeX math); needs a kitty-graphics terminal (kitty,
  WezTerm, Ghostty) and tmux allow-passthrough, and snacks `image` enabled
- fzf: Better integration of vim and fzf
- fzf: Better use of fzf
- keybindings: Re-rationalize keybindings across tools
  (windows/i3/tmux/vim/spacemacs/readline)
- keybindings: gqap behavior in markdown mode for better paragraph formatting
- shell: Directory jumpers comparison: wd vs z vs fasd (see
  https://github.com/rupa/z)
- tmux: tmux config import and auto-sync environment
- zsh: Manual config of zsh instead of using oh-my-zsh
