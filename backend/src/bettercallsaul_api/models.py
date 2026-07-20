from typing import Literal
from uuid import UUID

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: Literal["bettercallsaul-api"] = "bettercallsaul-api"


class AuthenticatedUser(BaseModel):
    id: UUID
