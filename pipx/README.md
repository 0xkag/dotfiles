# pipx

* `apps.json` -- the apps to install, as written by `pipx list --json`:
  each app's version and its injected packages.
* `install` -- installs the pinned pyenv Python (PYTHON_VERSION) if missing,
  pins pip, installs pipx into that Python's user site
  (reinstalling it only when its launcher points at another Python), runs
  `pipx ensurepath`, then runs `pipx install-all` on `apps.json` with that
  Python.  Apps already installed are left alone, so it is safe to re-run.

## Recording apps

`pipx install-all` installs each app at exactly the version `apps.json`
records, so regenerate it after any `pipx install`, `uninstall`, `inject`,
or upgrade, and commit it:

    pipx list --json > ~/.dotfiles/pipx/apps.json

Before committing, check `git diff apps.json` for a private package index:
the file records any `--pip-args` an app was installed with.

## Changing the Python version

Every app's venv is built on the Python that installed it, so changing
PYTHON_VERSION in `install` does not move existing apps.  `pipx
reinstall-all --python ...` would, but it reinstalls each app at its latest
release instead of its recorded version.  To move the apps and keep their
versions, record them, remove them, and reinstall from the record:

    pipx list --json > ~/.dotfiles/pipx/apps.json
    pipx uninstall-all
    ~/.dotfiles/pipx/install

Keep the old pyenv Python installed until nothing else uses it: pyenv
virtualenvs are built on it too (`pyenv versions`).

## Upgrading

`pipx upgrade <app>` upgrades only the app itself.  pip's default upgrade
strategy leaves a dependency alone if the installed version still meets the
app's requirements, so the venv's other packages stay at whatever they were
when the app was installed.  To upgrade the app and all of its dependencies:

    pipx runpip <app> install --upgrade --upgrade-strategy eager <app>

To upgrade only the dependencies, pin the app to its current version:

    pipx runpip <app> install --upgrade --upgrade-strategy eager '<app>==<version>'

Each dependency still goes only as high as the app's own requirements
allow.  For example, poetry requires `pkginfo<2.0`, so this caps pkginfo at
the latest 1.x.  Add `--include-injected` to `pipx upgrade` to also upgrade
packages added with `pipx inject`.
