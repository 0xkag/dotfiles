# vim: et sw=4 ts=4:

"""
{{ cookiecutter.cli_name }} command line interface.
"""

import click
import structlog

from {{ cookiecutter.package_path }} import (
    __version__,
)
from {{ cookiecutter.package_path }}.structlog_config import (
    structlog_configure,
)

@click.command()
@click.version_option(__version__)
def main():
    """
    {{ cookiecutter.description }}
    """

    structlog_configure()
    log = structlog.getLogger(__name__)

    log.info('starting', version=__version__)
