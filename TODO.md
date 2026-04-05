- binaries: Remove more `_lib` submodules in favor of just installing with
  mise (started this already)
- binaries: Capture standard set of pipx / mise installed things
- binaries: Rationalize use of mise vs. system package manager
- binaries: Support for NFS homedir mounted on multiple architectures (amd64
  and arm64); this is a problem for things like ~/.local, pyenv, pipx, and
  mise
- editor: vim git commit message fill column at 75
- fzf: Better integration of vim and fzf
- fzf: Better use of fzf
- keybindings: Re-rationalize keybindings across tools
  (windows/i3/tmux/vim/spacemacs/readline)
- keybindings: gqap behavior in markdown mode for better paragraph formatting
- shell: Directory jumpers comparison: wd vs z vs fasd (see
  https://github.com/rupa/z)
- tmux: tmux config import and auto-sync environment
- zsh: Manual config of zsh instead of using oh-my-zsh
