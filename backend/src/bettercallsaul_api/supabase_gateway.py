from typing import Any

import httpx

from bettercallsaul_api.config import Settings


JsonResponse = dict[str, Any] | list[Any]


class SupabaseGatewayError(RuntimeError):
    pass


class SupabaseGateway:
    allowed_service_rpcs = frozenset({"search_legal_chunks"})

    def __init__(self, settings: Settings, client: httpx.AsyncClient) -> None:
        self.settings = settings
        self.client = client

    async def user_request(
        self,
        method: str,
        path: str,
        access_token: str,
        json: dict[str, Any] | None = None,
    ) -> JsonResponse:
        self.settings.require_supabase()
        return await self._request(
            method=method,
            path=path,
            headers={
                "apikey": self.settings.supabase_publishable_key,
                "Authorization": f"Bearer {access_token}",
            },
            json=json,
        )

    async def service_rpc(
        self,
        name: str,
        payload: dict[str, Any],
    ) -> list[dict[str, Any]]:
        if name not in self.allowed_service_rpcs:
            raise ValueError("Service RPC is not allowed.")

        self.settings.require_supabase()
        self.settings.require_supabase_secret()
        response = await self._request(
            method="POST",
            path=f"/rest/v1/rpc/{name}",
            headers={
                "apikey": self.settings.supabase_secret_key,
                "Authorization": f"Bearer {self.settings.supabase_secret_key}",
            },
            json=payload,
        )
        if not isinstance(response, list) or not all(
            isinstance(item, dict) for item in response
        ):
            raise SupabaseGatewayError("Supabase request failed.")
        return response

    async def _request(
        self,
        *,
        method: str,
        path: str,
        headers: dict[str, str],
        json: dict[str, Any] | None,
    ) -> JsonResponse:
        url = f"{self.settings.supabase_url.rstrip('/')}/{path.lstrip('/')}"
        try:
            response = await self.client.request(
                method,
                url,
                headers=headers,
                json=json,
                timeout=10.0,
            )
            response.raise_for_status()
            if response.status_code == 204:
                return {}
            decoded = response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise SupabaseGatewayError("Supabase request failed.") from error

        if not isinstance(decoded, (dict, list)):
            raise SupabaseGatewayError("Supabase request failed.")
        return decoded
