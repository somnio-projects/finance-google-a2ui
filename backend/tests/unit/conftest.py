"""Mark every test under ``tests/unit`` as ``unit``."""

import pytest


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        if "/tests/unit/" in str(item.fspath):
            item.add_marker(pytest.mark.unit)
