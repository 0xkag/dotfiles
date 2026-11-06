"""
Tests for `{{ cookiecutter.package_path }}.structlog_config` unit.
"""

import structlog

from {{ cookiecutter.package_path }}.structlog_config import (
    StructlogSemanticSorter,
    structlog_processor_redact_event_dict,
)

def test_exception_expected(structlog_expect_exceptions):
    # pylint: disable=unused-argument

    try:
        raise ValueError('boom')
    except ValueError:
        structlog.getLogger(__name__).exception('expected')

def test_redact_event_dict():
    event_dict = structlog_processor_redact_event_dict(None, None, {
        'aws_secret_access_key': 'secret1',
        'event': "creds {'aws_session_token': 'secret2', 'region': 'x'}",
    })

    assert event_dict['aws_secret_access_key'] == '[REDACTED]'
    assert 'secret2' not in event_dict['event']
    assert "'region': 'x'" in event_dict['event']

def test_semantic_sorter():
    sorter = StructlogSemanticSorter(order=['level', 'thread'], tail=['event'])
    event_dict = sorter(None, None, {
        'beta': 1,
        'event': '',
        'level': 'info',
        'thread': 0,
        'zeta': 0,
    })

    # falsy (but not None) values survive in the order and tail keys too
    assert list(event_dict.items()) == [
        ('level', 'info'),
        ('thread', 0),
        ('beta', 1),
        ('zeta', 0),
        ('event', ''),
    ]
