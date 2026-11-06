.PHONY: clean clean-build clean-pyc clean-test coverage coverage-html-display \
develop dist help install lint test test-all

.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys

try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT

define PRINT_HELP_PYSCRIPT
import re, sys

# this bit of Python generates a list of targets and help strings for `make
# help`

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

BROWSER := python -c "$$BROWSER_PYSCRIPT"

help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

clean: clean-build clean-pyc clean-test ## remove all build, test, coverage and Python artifacts

clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -fr {} +

clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-test: ## remove test and coverage artifacts
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/
	rm -fr .pytest_cache

lint: ## check style with flake8
	poetry run flake8 {{ cookiecutter.__package_dir }}
	# W0511 is TODO / fixme
	poetry run pylint --disable W0511 {{ cookiecutter.__package_dir }}
	poetry run mypy -p {{ cookiecutter.package_path }}

test: ## run tests quickly with the default Python
	poetry run py.test --doctest-modules --import-mode=importlib -rx

test-all: ## run tests on every Python version with tox
	poetry run tox -r --develop

# --source is a path, not a dotted module name: --doctest-modules imports
# the package under a shorter name (the namespace dirs above it have no
# __init__.py), which a dotted --source does not match; coverage then skips
# those files for the rest of the run, even when tests import the full name
coverage: ## check code coverage quickly with the default Python
	poetry run coverage run --source {{ cookiecutter.__package_dir }} -m pytest --doctest-modules --import-mode=importlib -rx
	poetry run coverage report -m
	poetry run coverage html

coverage-html-display: coverage ## display the html coverage report
	$(BROWSER) htmlcov/index.html

develop:
	poetry install --with dev

dist: clean ## builds source and wheel package
	poetry build
	ls -l dist

install: clean dist ## install the package to the active Python's site-packages
	poetry install --only main --no-root
	pip install --no-index --no-deps --find-links dist {{ cookiecutter.dist_name }}

