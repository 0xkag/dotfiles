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

## Logging

`structlog_config.structlog_configure()` is called from `cli.main()` and from
`conftest.py`, never at import time, since this package may be imported as a
library by other projects.

## Tests

A test that logs an exception fails unless it requests the
`structlog_expect_exceptions` fixture; a doctest calls
`getfixture('structlog_expect_exceptions')` instead.
