from typing import Annotated

import httpx
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import ValidationError

from bettercallsaul_api.config import Settings
from bettercallsaul_api.models import AuthenticatedUser


bearer = HTTPBearer(auto_error=False)


def unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Требуется авторизация.",
    )


class SupabaseAuthVerifier:
    def __init__(self, settings: Settings, client: httpx.AsyncClient) -> None:
        self.settings = settings
        self.client = client

    async def verify(self, access_token: str) -> AuthenticatedUser:
        self.settings.require_supabase()
        try:
            response = await self.client.get(
                f"{self.settings.supabase_url.rstrip('/')}/auth/v1/user",
                headers={
                    "apikey": self.settings.supabase_publishable_key,
                    "Authorization": f"Bearer {access_token}",
                },
            )
        except httpx.HTTPError as error:
            raise unauthorized() from error

        if response.status_code != status.HTTP_200_OK:
            raise unauthorized()
        try:
            return AuthenticatedUser.model_validate(response.json())
        except (ValidationError, ValueError) as error:
            raise unauthorized() from error


def get_auth_verifier(request: Request) -> SupabaseAuthVerifier:
    return request.app.state.auth_verifier


async def require_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    verifier: Annotated[SupabaseAuthVerifier, Depends(get_auth_verifier)],
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise unauthorized()
    return await verifier.verify(credentials.credentials)
