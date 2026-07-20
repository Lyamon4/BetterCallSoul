from fastapi import FastAPI

from bettercallsaul_api.models import HealthResponse


def create_app() -> FastAPI:
    app = FastAPI(title="BetterCallSaul API", version="0.1.0")

    @app.get("/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse()

    return app


app = create_app()
