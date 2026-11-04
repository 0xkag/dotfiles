# mise

Tool installation via [mise](https://mise.jdx.dev/), run in shims mode (no
`mise activate`; see `_shell/shellenv` and `_shell/shellinteractive`).

* `check-tools` -- computes MISE_DISABLE_TOOLS, the tools mise should skip
  because a runnable copy exists outside mise (rpm/apt, flox, homedir build)
  that meets the version need.  Policies, minimums, and per-machine skips are
  documented in its header; per-machine overrides go in the site repo at
  `_sites/current/mise/check-tools.local` (see `check-tools.local.example`).
* `config.toml` -- the global tool list.
* `install` -- bootstraps mise itself, then installs the tools.
* `mise.lock` -- the lockfile, symlinked as `~/.config/mise/mise.lock`.

## Shell helpers

From `_shell/shellinteractive`:

* `mise-all` -- runs mise with MISE_DISABLE_TOOLS cleared, to see or manage
  the tools this host skips (`mise-all ls`, `mise-all ls -g`,
  `mise-all uninstall neovim`).  Plain mise does not see skipped tools at
  all: it lists, upgrades, and installs them as if they were not
  configured.  Arguments pass through unchanged, so `-g` and project scope
  work as in plain mise, surprise included: inside a project, `ls -g` lists
  only tools whose active version comes from the global config, omitting
  any global pin the project overrides; run it from `~` for the full list.
* `mise-bump` -- bumps tools to their newest eligible release: the current
  project's pins by default, the global ones with `-g` (see "Bumping
  versions").
* `mise-lock` -- refreshes a lockfile: the current project's by default, the
  global one with `-g` (see "Lockfile").
* `mise-refresh` -- recomputes MISE_DISABLE_TOOLS after a system or flox
  tool is added or removed.

## Lockfile

`config.toml` sets `locked = true`, so installs use only what `mise.lock`
records and never rewrite it.  After changing `config.toml` (adding a tool,
or changing a version or a tool option), refresh the lockfile with
`mise-lock -g` (from `_shell/shellinteractive`), then commit it:

    mise-lock -g               # every tool
    mise-lock -g yazi          # only the named tools
    mise-lock -g --bump rust   # move rust = "latest" forward

`mise-lock` runs `mise lock` with locked mode off (a plain `mise lock`
fails with "... is not in the lockfile" for any changed tool), with
MISE_DISABLE_TOOLS cleared so skipped tools stay locked, and with
MISE_PYPI_REGISTRY_URL removed (see "Private package indexes").  Its
arguments pass through unchanged, so like `mise lock` it locks the current
project's lockfile without `-g`; with `-g`, mise ignores any project config.

This repo's lockfile always needs `-g`, even from inside `~/.dotfiles`:
MISE_IGNORED_CONFIG_PATHS (see `_shell/shellenv`) hides `mise/config.toml`
as a project config there, so `mise-lock` or `mise-bump` without `-g` finds
no project tools and does nothing (`mise-bump` misleadingly reports "All
tools are up to date").

### Bumping versions

`mise-bump` moves tools past their pins to the newest release older than
`minimum_release_age`, installs them, and locks them on every platform,
then `config.toml` and `mise.lock` get committed together:

    mise-bump -g awscli fd
    mise-bump -g --dry-run awscli  # show what would change

With `-g` it runs `mise upgrade --global --bump` with locked mode off, then
`mise-lock -g` for the same tools.  Without `-g` it runs `mise upgrade
--local --bump`, then `mise-lock`, to bump a project's pins and lockfile
instead; `--local` keeps the bump to the project's config root, the one
`mise-lock` locks, where plain `mise upgrade` would also bump global pins
the project does not override.  A plain `mise upgrade --bump` fails
under locked mode after already rewriting the pin, leaving `config.toml`
bumped but `mise.lock` not, and every later mise command warns until
`mise-lock -g TOOL` catches the lockfile up.

Tools this host skips are invisible to plain mise, so `mise-bump` refuses
them.  Bump a skipped tool with `mise-all`, which also installs it here
(where the exclusion hides it again), or edit its pin by hand and lock it:

    MISE_LOCKED=false mise-all upgrade --global --bump ripgrep && \
        mise-lock -g ripgrep
    mise-lock -g ripgrep           # after editing the pin by hand

For a project's pin, use `--local` and `mise-lock` without `-g` instead.

Never run `mise-all upgrade --bump` without tool names: it bumps every tool
at once and installs every skipped one on this host.  `mise-bump` refuses
to run without at least one tool name for the same reason.

`mise.lock` is still lockfile format 0, which mise warns about after
2027-02-23.  Older mise cannot read newer formats, so only once every machine
sharing these dotfiles runs mise 2026.10.19 or newer, upgrade it to the
current format, from a host with direct PyPI access (see below), and commit
it:

    mise-lock -g --upgrade

### Private package indexes

`mise.lock` is shared, so it must never record a site's private package
index (such as a Nexus PyPI proxy).  mise ignores pip.conf: it passes
`pypi.registry_url` (default PyPI) to pipx and uv as PIP_INDEX_URL and
UV_INDEX, which take precedence over config files.  Where PyPI is blocked,
point a one-off install at the proxy.  `mise-lock` drops
MISE_PYPI_REGISTRY_URL from its environment but cannot strip
`pypi.registry_url` from a config file, so never set it there:

    MISE_PYPI_REGISTRY_URL='https://<proxy>/simple/{}/' MISE_PIPX_UVX=false \
        mise-all install yamllint

On format 0 a lock run records only a version for Python tools, and works
even where PyPI downloads are blocked.  Newer formats also store dependency
graphs for Python tools, so locking yamllint will likely need PyPI there:
on such hosts lock only the tools that changed (`mise-lock -g TOOL...`) and run
full locks from a host with direct PyPI access.
Before committing, check `git diff mise.lock` for the private host.

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
