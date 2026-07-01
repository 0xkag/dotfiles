# mise

Tool installation via [mise](https://mise.jdx.dev/), run in shims mode (no
`mise activate`; see `_shell/shellenv` and `_shell/shellinteractive`).

* `check-tools` -- computes MISE_DISABLE_TOOLS, the tools mise should skip
  because a runnable copy exists outside mise (rpm/apt, flox, homedir build)
  that meets the version need.  Policies, minimums, and per-machine skips are
  documented in its header; per-machine overrides go in the untracked
  `check-tools.local` (see `check-tools.local.example`).
* `config.toml` -- the global tool list.
* `install` -- bootstraps mise itself, then installs the tools.

## Troubleshooting

### pre-commit: `AttributeError: 'PythonInfo' object has no attribute ...`

mise installs pre-commit as a zipapp with a bundled copy of virtualenv.  Every
copy of virtualenv (standalone, tox's, or this bundled one) shares a cache of
interpreter introspection data at:

    ~/.local/share/virtualenv/py_info/

Entries are PythonInfo JSON snapshots keyed by interpreter path + mtime, in a
schema-versioned subdir.  Nothing prunes this cache, and a newer virtualenv
trusts entries written by an older one even when the older schema lacks fields
the newer code reads (e.g. `tcl_lib`).  The result is an AttributeError from
deep inside `-mvirtualenv` whenever pre-commit installs a hook environment --
typically at commit/rebase time, while `pre-commit --help` still works.

Fix: clear the cache and let virtualenv rebuild it:

    rm -rf ~/.local/share/virtualenv/py_info
