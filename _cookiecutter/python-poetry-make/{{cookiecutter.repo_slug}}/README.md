# {{ cookiecutter.repo_slug }}

{{ cookiecutter.description }}

## Development

Requires Python 3.12, 3.13, or 3.14 and poetry.

* `make develop` -- install into a poetry virtualenv, with dev dependencies
* `make lint` -- flake8, pylint, and mypy
* `make test` -- pytest, including doctests
* `make coverage` -- coverage report, plus HTML in `htmlcov/`
* `make test-all` -- tox across every supported Python
* `make help` -- list all targets

Run `make lint` and `make test` before committing.

