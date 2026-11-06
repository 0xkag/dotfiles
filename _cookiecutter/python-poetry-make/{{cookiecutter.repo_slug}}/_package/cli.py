# vim: et sw=4 ts=4:

"""
{{ cookiecutter.cli_name }} command line interface.
"""

import sys

import click
import structlog

from {{ cookiecutter.package_path }} import (
    __version__,
)

@click.command()
@click.version_option(__version__)
def main():
    """
    {{ cookiecutter.description }}
    """

    structlog.configure(
        logger_factory=structlog.PrintLoggerFactory(sys.stderr),
    )
    log = structlog.getLogger(__name__)

    log.info('starting', version=__version__)
