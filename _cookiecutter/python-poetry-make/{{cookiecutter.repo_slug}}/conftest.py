"""
Shared pytest fixtures and hooks.  This lives at the repo root, not in tests/,
so that it also applies to the package's doctests.
"""

import pytest

from {{ cookiecutter.package_path }} import (
    structlog_config,
)

@pytest.hookimpl(wrapper=True)
def pytest_runtest_call():
    """
    Fail a test that logged an exception, unless it requested the
    structlog_expect_exceptions fixture.  This runs right after the test body,
    so pytest reports the test as FAILED rather than as an ERROR at teardown.
    """

    # pylint: disable=protected-access

    result = yield

    exceptions = structlog_config._test_logged_exceptions

    if exceptions and not structlog_config._test_expect_errors_active:
        msgs = [
            f'  {event} ({exc_info[0].__name__}: {exc_info[1]})'
            for event, exc_info in exceptions
        ]
        pytest.fail(
            f'Logged {len(exceptions)} unexpected exception(s):\n' +
            '\n'.join(msgs)
        )

    return result

@pytest.fixture
def structlog_expect_exceptions():
    """
    Request this fixture in a test that is expected to log exceptions.  In a
    doctest, call getfixture('structlog_expect_exceptions') instead.
    """

    # pylint: disable=protected-access

    # autouse fixtures run first, so this overrides structlog_exceptions_track

    structlog_config._test_expect_errors_active = True

@pytest.fixture(autouse=True)
def structlog_exceptions_track():
    """
    Configure logging for each test (so handlers bind to that test's captured
    stderr) and record exceptions it logs, for pytest_runtest_call to check.
    """

    # pylint: disable=protected-access

    structlog_config.structlog_configure()
    structlog_config._test_logged_exceptions = []
    structlog_config._test_expect_errors_active = False

    yield

    structlog_config._test_logged_exceptions = None
    structlog_config._test_expect_errors_active = False
