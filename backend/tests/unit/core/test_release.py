import pytest

from app import __version__
from app.core.release import resolve_release


@pytest.mark.parametrize(
    ("configured", "expected"),
    [
        ("0.1.0+abc1234", "0.1.0+abc1234"),
        ("  0.1.0+abc1234  ", "0.1.0+abc1234"),
        ("", __version__),
        ("   ", __version__),
    ],
    ids=["set", "padded", "blank", "whitespace"],
)
def test_resolve_release_prefers_the_injected_identifier_over_the_package_version(
    configured: str, expected: str
) -> None:
    assert resolve_release(configured) == expected
