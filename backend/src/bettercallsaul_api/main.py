from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated

import httpx
from fastapi import Depends, FastAPI

from bettercallsaul_api.auth import SupabaseAuthVerifier, require_user
from bettercallsaul_api.config import Settings, get_settings
from bettercallsaul_api.models import AuthenticatedUser, HealthResponse


def create_app(
    settings: Settings | None = None,
    transport: httpx.AsyncBaseTransport | None = None,
) -> FastAPI:
    resolved_settings = settings or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(10.0),
            transport=transport,
        ) as client:
            app.state.auth_verifier = SupabaseAuthVerifier(
                settings=resolved_settings,
                client=client,
            )
            yield

    app = FastAPI(
        title="BetterCallSaul API",
        version="0.1.0",
        lifespan=lifespan,
    )

    @app.get("/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse()

    @app.get("/v1/me", response_model=AuthenticatedUser)
    async def me(
        user: Annotated[AuthenticatedUser, Depends(require_user)],
    ) -> AuthenticatedUser:
        return user

    return app


app = create_app()
