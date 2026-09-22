"""Spec 0006 AC-1/AC-5 — configuration is read once, by the factory."""

from app.core.protocols import ModelClient
from app.infra.model.factory import build_model_client
from app.infra.model.gemini_client import GeminiModelClient
from app.infra.model.scripted_client import ScriptedModelClient
from tests.conftest import make_settings


def test_build_model_client_without_a_key_returns_the_scripted_client() -> None:
    """Spec 0033 AC-1 — no key means the demo's script, not silence."""
    client: ModelClient = build_model_client(make_settings())

    assert isinstance(client, ScriptedModelClient)
    assert client.name == "scripted"


def test_build_model_client_with_a_key_returns_the_gemini_adapter() -> None:
    settings = make_settings(
        gemini_api_key="placeholder-not-a-real-key",  # gitleaks:allow - test fixture
        gemini_model="gemini-test",
    )

    client: ModelClient = build_model_client(settings)

    assert isinstance(client, GeminiModelClient)
    assert client.name == "gemini-test"
