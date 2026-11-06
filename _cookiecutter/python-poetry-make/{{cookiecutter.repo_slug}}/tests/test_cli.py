"""
Tests for `{{ cookiecutter.package_path }}.cli` unit.
"""

from click.testing import (
    CliRunner,
)

from {{ cookiecutter.package_path }} import (
    __version__,
    cli,
)

def test_main():
    result = CliRunner().invoke(cli.main, [])
    assert result.exit_code == 0, result.output

def test_version():
    result = CliRunner().invoke(cli.main, ['--version'])
    assert result.exit_code == 0
    assert __version__ in result.output
