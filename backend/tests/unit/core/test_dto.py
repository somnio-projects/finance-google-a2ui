from types import SimpleNamespace

import pytest
from pydantic import BaseModel, ConfigDict

from app.core.dto import from_row
from app.core.errors import DependencyUnavailableError


class _Dto(BaseModel):
    model_config = ConfigDict(frozen=True, from_attributes=True)

    key: str
    enabled: bool


def test_from_row_maps_matching_attributes_to_the_dto() -> None:
    dto = from_row(_Dto, SimpleNamespace(key="k", enabled=True, extra="ignored"))
    assert dto == _Dto(key="k", enabled=True)


def test_from_row_translates_validation_error_to_dependency_unavailable() -> None:
    with pytest.raises(DependencyUnavailableError, match="stored data") as info:
        from_row(_Dto, SimpleNamespace(key="k"))
    assert info.value.__cause__ is not None
