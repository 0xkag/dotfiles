- Manual config of zsh instead of using oh-my-zsh
- Better integration of vim and fzf
- Better use of fzf
- Fully integrate mise (now that I've disabled automatic asdf in `_shell`)
- Remove some `_lib` submodules in favor of just installing with mise
- Capture standard set of pipx / mise installed things
- Support for NFS homedir mounted on multiple architectures (amd64 and arm64);
  this is a problem for things like ~/.local, pyenv, and mise
- Overhaul vimrc for newer features
