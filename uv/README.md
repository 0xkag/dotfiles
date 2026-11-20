# uv

This repo installs no uv config.  A site repo may link one as
`~/.config/uv/uv.toml` (see `_sites/current/_bin/dotfiles-install-site`),
for example to make a private package index the default where PyPI is
blocked.

## Private package indexes in uv.lock

A project's `uv.lock` records the index each package came from and its
download URLs.  With a private default index in `~/.config/uv/uv.toml`,
`uv lock` writes that index's address into `uv.lock`, and rewrites a
lockfile that pointed at PyPI; `uv sync` and `uv run` lock first, so they
do the same.  That is fine for a project only built inside that network.
Anywhere else it leaks the address and breaks the lockfile for everyone
outside the network.

Before committing, check `git diff uv.lock` for the private host, and undo
a rewrite with `git checkout uv.lock`.  `--locked` makes uv fail instead of
rewriting the lockfile:

    uv sync --locked
