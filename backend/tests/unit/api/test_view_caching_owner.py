"""The greeting is in the body, so it is in the entity tag (spec 0030)."""

from fastapi.testclient import TestClient

from app.api.deps.views import get_owner_resolver
from app.core.principal import Principal
from app.domain.persona import PortfolioOwner
from tests.unit.api.test_view_caching import AUTH, VIEWS_URL


class _NamesPriya:
    async def owner_for(self, principal: Principal) -> PortfolioOwner | None:
        del principal
        return PortfolioOwner(name="Priya Natarajan", initial="P")


def test_who_is_greeted_is_part_of_the_entity_tag(views_client: TestClient) -> None:
    """Spec 0030 — the greeting is in the body, so it is in the tag.

    Found in the browser: the first run after signing in showed the persona,
    because the body had changed and the tag had not, and the request
    revalidated to 304 against the cached greeting.
    """
    url = f"{VIEWS_URL}?view=portfolio.summary.v1"
    anonymous = views_client.get(url, headers=AUTH).headers["ETag"]
    views_client.app.dependency_overrides[get_owner_resolver] = _NamesPriya  # type: ignore[attr-defined]
    named = views_client.get(url, headers=AUTH)

    assert named.status_code == 200
    assert named.headers["ETag"] != anonymous
    assert named.json()["views"]["portfolio.summary.v1"]["account"]["name"] == (
        "Priya Natarajan"
    )
