create or replace function public.search_legal_chunks(
  query_text text,
  query_embedding extensions.vector(768),
  case_category text,
  relevant_on date default current_date,
  match_count integer default 12
)
returns table (
  chunk_id bigint,
  provision_id bigint,
  source_code text,
  source_title text,
  provision_code text,
  heading text,
  content text,
  official_url text,
  revision_code text,
  effective_from date,
  effective_to date,
  score double precision
)
language sql
stable
security definer
set search_path = ''
as $$
  with eligible as (
    select
      c.id as chunk_id,
      p.id as provision_id,
      s.source_code,
      s.title as source_title,
      p.provision_code,
      p.heading,
      c.content,
      s.official_url,
      r.revision_code,
      r.effective_from,
      r.effective_to,
      p.search_vector,
      c.embedding
    from rag.legal_chunks c
    join rag.legal_provisions p on p.id = c.provision_id
    join rag.legal_revisions r on r.id = p.revision_id
    join rag.legal_sources s on s.id = r.source_id
    where r.status = 'active'
      and s.is_active
      and case_category = any(p.categories)
      and (r.effective_from is null or r.effective_from <= relevant_on)
      and (r.effective_to is null or r.effective_to >= relevant_on)
  ),
  full_text as (
    select chunk_id, row_number() over (
      order by ts_rank_cd(
        search_vector,
        websearch_to_tsquery('russian', query_text)
      ) desc
    ) as rank
    from eligible
    where search_vector @@ websearch_to_tsquery('russian', query_text)
    limit least(match_count * 4, 100)
  ),
  semantic as (
    select
      chunk_id,
      row_number() over (
        order by embedding OPERATOR(extensions.<=>) query_embedding
      ) as rank
    from eligible
    order by embedding OPERATOR(extensions.<=>) query_embedding
    limit least(match_count * 4, 100)
  ),
  fused as (
    select
      coalesce(full_text.chunk_id, semantic.chunk_id) as chunk_id,
      coalesce(1.0 / (50 + full_text.rank), 0.0)
        + coalesce(1.0 / (50 + semantic.rank), 0.0) as score
    from full_text
    full join semantic using (chunk_id)
  )
  select
    e.chunk_id,
    e.provision_id,
    e.source_code,
    e.source_title,
    e.provision_code,
    e.heading,
    e.content,
    e.official_url,
    e.revision_code,
    e.effective_from,
    e.effective_to,
    f.score
  from fused f
  join eligible e on e.chunk_id = f.chunk_id
  order by f.score desc, e.chunk_id
  limit greatest(1, least(match_count, 50));
$$;

revoke all on function public.search_legal_chunks(
  text,
  extensions.vector,
  text,
  date,
  integer
) from public, anon, authenticated;

grant execute on function public.search_legal_chunks(
  text,
  extensions.vector,
  text,
  date,
  integer
) to service_role;
