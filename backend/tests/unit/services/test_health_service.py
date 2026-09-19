from app.services.health_service import HealthService


class Probe:
    def __init__(self, name: str, ready: bool) -> None:
        self.name = name
        self._ready = ready

    async def check(self) -> bool:
        return self._ready


def test_liveness_reports_version_without_touching_probes() -> None:
    service = HealthService(version="1.2.3", probes=[Probe("db", False)])
    result = service.liveness()
    assert result.status == "ok"
    assert result.version == "1.2.3"


async def test_readiness_is_ready_when_all_probes_pass() -> None:
    service = HealthService(version="v", probes=[Probe("db", True), Probe("idp", True)])
    result = await service.readiness()
    assert result.status == "ready"
    assert [(d.name, d.ready) for d in result.dependencies] == [
        ("db", True),
        ("idp", True),
    ]


async def test_readiness_is_degraded_when_any_probe_fails() -> None:
    service = HealthService(
        version="v", probes=[Probe("db", False), Probe("idp", True)]
    )
    result = await service.readiness()
    assert result.status == "degraded"
    assert result.dependencies[0].ready is False
    assert result.http_status == 503


async def test_readiness_with_no_probes_is_ready() -> None:
    result = await HealthService(version="v", probes=[]).readiness()
    assert result.status == "ready"
    assert result.http_status == 200
    assert result.dependencies == []
