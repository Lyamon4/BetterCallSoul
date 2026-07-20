# BetterCallSaul

BetterCallSaul is an iOS legal-workflow assistant for Kazakhstan. The current
foundation contains the existing SwiftUI client, an authenticated FastAPI
backend, owner-scoped Supabase case storage, and a protected hybrid-search
schema for the future official legal corpus.

For a fresh local iOS checkout, create the ignored secrets file before opening
the Xcode project:

```bash
cp ios/Config/Secrets.xcconfig.example ios/Config/Secrets.xcconfig
```

Fill it locally or through your team secret manager. Never commit the populated
file.

## Backend

Requirements: `uv` and Python 3.12. The repository locks the complete Python
dependency graph in `backend/uv.lock`.

```bash
cd backend
uv sync --python 3.12
cp .env.example .env
uv run uvicorn bettercallsaul_api.main:app --reload
```

The backend exposes:

- `GET /health` without provider credentials;
- `GET /v1/me` with a valid Supabase Bearer token.

Required environment-variable names:

```dotenv
ENVIRONMENT=development
SUPABASE_URL=
SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SECRET_KEY=
```

`SUPABASE_SECRET_KEY` is backend-only. Never copy it into the iOS project,
including `ios/Config/Secrets.xcconfig`, and never commit a populated
`backend/.env`.

Run the backend suite with:

```bash
cd backend
uv run pytest -q
uv run pytest --cov=bettercallsaul_api --cov-report=term-missing -q
```

## Supabase RAG foundation

Migrations are stored in `supabase/migrations` and have been applied to the
connected project in this order:

1. `20260720170000_rag_foundation.sql`
2. `20260720171000_hybrid_legal_search.sql`

The `public` case tables use owner-based RLS. The legal corpus lives in the
private `rag` schema with access revoked from `PUBLIC`, `anon`, and
`authenticated`. The `public.search_legal_chunks` security-definer RPC has a
fixed empty `search_path` and is executable only by `service_role`.

To verify the database safely, run `supabase/tests/rag_foundation.sql` in the
Supabase SQL editor or through the connected Supabase tooling. The test opens a
transaction, checks the extension, tables, RLS, function security, and grants,
then rolls back.

The schema is intentionally empty until the legal-ingestion phase imports and
validates versioned text from official Kazakhstan sources. Do not place user
photos, PDFs, or private evidence in the RAG corpus.
