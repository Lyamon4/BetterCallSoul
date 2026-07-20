create extension if not exists vector with schema extensions;

create schema if not exists rag;

revoke all on schema rag from public, anon, authenticated;

create table rag.legal_sources (
  id bigint generated always as identity primary key,
  source_code text not null unique,
  title text not null,
  authority text not null,
  official_url text not null unique,
  jurisdiction text not null default 'KZ' check (jurisdiction = 'KZ'),
  language text not null default 'ru' check (language in ('ru', 'kk')),
  document_type text not null,
  adopted_on date,
  is_allowlisted boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table rag.legal_revisions (
  id bigint generated always as identity primary key,
  source_id bigint not null references rag.legal_sources(id) on delete cascade,
  revision_code text not null,
  effective_from date,
  effective_to date,
  fetched_at timestamptz not null default now(),
  content_checksum text not null,
  parser_version text not null,
  normalized_text text not null,
  status text not null check (
    status in ('staged', 'validated', 'active', 'superseded', 'rejected')
  ),
  created_at timestamptz not null default now(),
  unique (source_id, revision_code),
  check (
    effective_to is null
    or effective_from is null
    or effective_to >= effective_from
  )
);

create table rag.legal_provisions (
  id bigint generated always as identity primary key,
  revision_id bigint not null references rag.legal_revisions(id) on delete cascade,
  provision_code text not null,
  heading text,
  hierarchy_path text not null,
  normalized_text text not null,
  source_anchor text,
  categories text[] not null default '{}',
  sectors text[] not null default '{}',
  content_checksum text not null,
  search_vector tsvector generated always as (
    to_tsvector('russian', coalesce(heading, '') || ' ' || normalized_text)
  ) stored,
  unique (revision_id, provision_code)
);

create table rag.legal_chunks (
  id bigint generated always as identity primary key,
  provision_id bigint not null references rag.legal_provisions(id) on delete cascade,
  sequence_no integer not null check (sequence_no >= 0),
  content text not null,
  context_heading text not null,
  token_count integer not null check (token_count > 0),
  embedding extensions.vector(768) not null,
  embedding_model text not null,
  embedding_version text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (provision_id, sequence_no)
);

create table rag.ingestion_runs (
  id bigint generated always as identity primary key,
  source_id bigint not null references rag.legal_sources(id) on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null check (
    status in ('running', 'succeeded', 'failed', 'unchanged')
  ),
  parser_version text not null,
  embedding_model text not null,
  fetched_checksum text,
  revision_count integer not null default 0 check (revision_count >= 0),
  provision_count integer not null default 0 check (provision_count >= 0),
  chunk_count integer not null default 0 check (chunk_count >= 0),
  validation_errors jsonb not null default '[]'::jsonb,
  operator_notes text
);

create table public.cases (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (
    category in ('charge', 'fine', 'subscription', 'product', 'bill')
  ),
  status text not null default 'draft' check (
    status in (
      'draft',
      'researching',
      'needs_input',
      'strategy_ready',
      'document_ready',
      'sent',
      'waiting',
      'action_required',
      'closed'
    )
  ),
  narrative text not null default '',
  counterparty text,
  amount numeric(14,2),
  currency text not null default 'KZT',
  confirmed_fields jsonb not null default '{}'::jsonb,
  completeness jsonb not null default '{}'::jsonb,
  next_action_at timestamptz,
  response_deadline timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.case_answers (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  question_id text not null,
  value text not null,
  provenance text not null check (provenance in ('user', 'evidence', 'system')),
  is_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (case_id, question_id)
);

create table public.case_evidence (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  file_name text not null,
  mime_type text not null,
  extracted_text text not null default '',
  reviewed_fields jsonb not null default '{}'::jsonb,
  content_checksum text not null,
  analyzer_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.case_strategies (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  revision_no integer not null check (revision_no > 0),
  summary text not null,
  recommended_action text not null,
  alternative_actions jsonb not null default '[]'::jsonb,
  warnings jsonb not null default '[]'::jsonb,
  completeness_report jsonb not null,
  source_manifest jsonb not null default '[]'::jsonb,
  status text not null check (
    status in ('blocked', 'review', 'approved', 'superseded')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (case_id, revision_no)
);

create table public.generated_documents (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  revision_no integer not null check (revision_no > 0),
  structured_sections jsonb not null,
  rendered_text_checksum text not null,
  source_manifest_checksum text not null,
  status text not null check (
    status in ('blocked', 'draft', 'ready', 'sent', 'superseded')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (case_id, revision_no)
);

create table public.document_citations (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.generated_documents(id) on delete cascade,
  chunk_id bigint not null references rag.legal_chunks(id) on delete restrict,
  provision_id bigint not null references rag.legal_provisions(id) on delete restrict,
  supported_proposition text not null,
  display_label text not null,
  official_url text not null,
  created_at timestamptz not null default now(),
  unique (document_id, chunk_id, supported_proposition)
);

create table public.case_events (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  event_type text not null,
  occurred_at timestamptz not null default now(),
  delivery_method text,
  delivery_reference text,
  actor text not null check (actor in ('user', 'system', 'provider')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index legal_revisions_source_status_effective_idx
  on rag.legal_revisions(source_id, status, effective_from);
create index legal_provisions_revision_idx on rag.legal_provisions(revision_id);
create index legal_provisions_search_idx
  on rag.legal_provisions using gin(search_vector);
create index legal_provisions_categories_idx
  on rag.legal_provisions using gin(categories);
create index legal_provisions_sectors_idx
  on rag.legal_provisions using gin(sectors);
create index legal_chunks_provision_idx on rag.legal_chunks(provision_id);
create index legal_chunks_embedding_hnsw_idx
  on rag.legal_chunks using hnsw (embedding vector_cosine_ops);
create index ingestion_runs_source_idx
  on rag.ingestion_runs(source_id, started_at desc);

create index cases_owner_updated_idx
  on public.cases(owner_id, updated_at desc);
create index case_answers_case_idx on public.case_answers(case_id);
create index case_evidence_case_idx on public.case_evidence(case_id);
create index case_strategies_case_idx on public.case_strategies(case_id);
create index generated_documents_case_idx on public.generated_documents(case_id);
create index document_citations_document_idx
  on public.document_citations(document_id);
create index document_citations_chunk_idx on public.document_citations(chunk_id);
create index document_citations_provision_idx
  on public.document_citations(provision_id);
create index case_events_case_idx
  on public.case_events(case_id, occurred_at desc);

alter table public.cases enable row level security;
alter table public.case_answers enable row level security;
alter table public.case_evidence enable row level security;
alter table public.case_strategies enable row level security;
alter table public.generated_documents enable row level security;
alter table public.document_citations enable row level security;
alter table public.case_events enable row level security;

create or replace function public.is_case_owner(target_case_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.cases c
    where c.id = target_case_id
      and c.owner_id = (select auth.uid())
  );
$$;

revoke all on function public.is_case_owner(uuid) from public, anon;
grant execute on function public.is_case_owner(uuid) to authenticated;

create policy cases_own_all on public.cases
for all to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create policy case_answers_own_all on public.case_answers
for all to authenticated
using ((select public.is_case_owner(case_id)))
with check ((select public.is_case_owner(case_id)));

create policy case_evidence_own_all on public.case_evidence
for all to authenticated
using ((select public.is_case_owner(case_id)))
with check ((select public.is_case_owner(case_id)));

create policy case_strategies_own_all on public.case_strategies
for all to authenticated
using ((select public.is_case_owner(case_id)))
with check ((select public.is_case_owner(case_id)));

create policy generated_documents_own_all on public.generated_documents
for all to authenticated
using ((select public.is_case_owner(case_id)))
with check ((select public.is_case_owner(case_id)));

create policy case_events_own_all on public.case_events
for all to authenticated
using ((select public.is_case_owner(case_id)))
with check ((select public.is_case_owner(case_id)));

create policy document_citations_own_all on public.document_citations
for all to authenticated
using (
  exists (
    select 1
    from public.generated_documents d
    where d.id = document_id
      and (select public.is_case_owner(d.case_id))
  )
)
with check (
  exists (
    select 1
    from public.generated_documents d
    where d.id = document_id
      and (select public.is_case_owner(d.case_id))
  )
);

revoke all on
  public.cases,
  public.case_answers,
  public.case_evidence,
  public.case_strategies,
  public.generated_documents,
  public.document_citations,
  public.case_events
from public, anon, authenticated;

grant usage on schema public to authenticated;
grant select, insert, update, delete on
  public.cases,
  public.case_answers,
  public.case_evidence,
  public.case_strategies,
  public.generated_documents,
  public.document_citations,
  public.case_events
to authenticated;

revoke all on all tables in schema rag from public, anon, authenticated;
revoke all on all sequences in schema rag from public, anon, authenticated;
