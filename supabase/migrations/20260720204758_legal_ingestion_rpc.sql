alter table rag.ingestion_runs
  add column revision_id bigint references rag.legal_revisions(id) on delete set null;

create index ingestion_runs_revision_idx
  on rag.ingestion_runs(revision_id)
  where revision_id is not null;

alter table rag.legal_sources enable row level security;
alter table rag.legal_revisions enable row level security;
alter table rag.legal_provisions enable row level security;
alter table rag.legal_chunks enable row level security;
alter table rag.ingestion_runs enable row level security;

create or replace function public.start_legal_ingestion(
  p_source jsonb,
  p_revision jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_id bigint;
  v_revision_id bigint;
  v_run_id bigint;
  v_active_revision_id bigint;
  v_source_code text := nullif(btrim(p_source->>'source_code'), '');
  v_official_url text := nullif(btrim(p_source->>'official_url'), '');
  v_revision_code text := nullif(btrim(p_revision->>'revision_code'), '');
  v_content_checksum text := nullif(btrim(p_revision->>'content_checksum'), '');
  v_parser_version text := nullif(btrim(p_revision->>'parser_version'), '');
  v_embedding_model text := nullif(btrim(p_revision->>'embedding_model'), '');
begin
  if v_source_code is null
    or v_official_url is null
    or nullif(btrim(p_source->>'title'), '') is null
    or nullif(btrim(p_source->>'authority'), '') is null
    or nullif(btrim(p_source->>'document_type'), '') is null
    or v_revision_code is null
    or v_content_checksum is null
    or v_parser_version is null
    or v_embedding_model is null
    or nullif(btrim(p_revision->>'normalized_text'), '') is null
  then
    raise exception 'Invalid legal ingestion payload.';
  end if;

  if v_source_code !~ '^[a-z][a-z0-9_]+$'
    or v_content_checksum !~ '^[a-f0-9]{64}$'
    or v_official_url !~ '^https://(adilet\.zan\.kz|www\.adilet\.zan\.kz|egov\.kz|www\.gov\.kz)/'
    or coalesce(p_source->>'jurisdiction', 'KZ') <> 'KZ'
    or coalesce(p_source->>'language', 'ru') not in ('ru', 'kk')
  then
    raise exception 'Invalid legal ingestion payload.';
  end if;

  select s.id
  into v_source_id
  from rag.legal_sources s
  where s.source_code = v_source_code
  for update;

  if v_source_id is not null and exists (
    select 1
    from rag.legal_sources s
    where s.id = v_source_id
      and s.official_url <> v_official_url
  ) then
    raise exception 'Official source URL cannot be changed.';
  end if;

  insert into rag.legal_sources (
    source_code,
    title,
    authority,
    official_url,
    jurisdiction,
    language,
    document_type,
    adopted_on,
    is_allowlisted,
    is_active
  )
  values (
    v_source_code,
    btrim(p_source->>'title'),
    btrim(p_source->>'authority'),
    v_official_url,
    coalesce(p_source->>'jurisdiction', 'KZ'),
    coalesce(p_source->>'language', 'ru'),
    btrim(p_source->>'document_type'),
    nullif(p_source->>'adopted_on', '')::date,
    true,
    true
  )
  on conflict (source_code) do update
  set title = excluded.title,
      authority = excluded.authority,
      document_type = excluded.document_type,
      adopted_on = coalesce(excluded.adopted_on, rag.legal_sources.adopted_on),
      is_allowlisted = true,
      is_active = true
  returning id into v_source_id;

  select r.id
  into v_active_revision_id
  from rag.legal_revisions r
  where r.source_id = v_source_id
    and r.status = 'active'
    and r.content_checksum = v_content_checksum
  limit 1;

  if v_active_revision_id is not null then
    insert into rag.ingestion_runs (
      source_id,
      revision_id,
      finished_at,
      status,
      parser_version,
      embedding_model,
      fetched_checksum,
      revision_count,
      provision_count,
      chunk_count
    )
    values (
      v_source_id,
      v_active_revision_id,
      now(),
      'unchanged',
      v_parser_version,
      v_embedding_model,
      v_content_checksum,
      0,
      (
        select count(*)
        from rag.legal_provisions p
        where p.revision_id = v_active_revision_id
      ),
      (
        select count(*)
        from rag.legal_chunks c
        join rag.legal_provisions p on p.id = c.provision_id
        where p.revision_id = v_active_revision_id
      )
    )
    returning id into v_run_id;

    return jsonb_build_object(
      'status', 'unchanged',
      'source_id', v_source_id,
      'revision_id', v_active_revision_id,
      'run_id', v_run_id
    );
  end if;

  if exists (
    select 1
    from rag.legal_revisions r
    where r.source_id = v_source_id
      and r.revision_code = v_revision_code
      and r.status = 'active'
  ) then
    raise exception 'Active revision code cannot be replaced.';
  end if;

  delete from rag.legal_revisions r
  where r.source_id = v_source_id
    and r.revision_code = v_revision_code
    and r.status <> 'active';

  insert into rag.legal_revisions (
    source_id,
    revision_code,
    effective_from,
    effective_to,
    fetched_at,
    content_checksum,
    parser_version,
    normalized_text,
    status
  )
  values (
    v_source_id,
    v_revision_code,
    nullif(p_revision->>'effective_from', '')::date,
    nullif(p_revision->>'effective_to', '')::date,
    now(),
    v_content_checksum,
    v_parser_version,
    p_revision->>'normalized_text',
    'staged'
  )
  returning id into v_revision_id;

  insert into rag.ingestion_runs (
    source_id,
    revision_id,
    status,
    parser_version,
    embedding_model,
    fetched_checksum,
    revision_count
  )
  values (
    v_source_id,
    v_revision_id,
    'running',
    v_parser_version,
    v_embedding_model,
    v_content_checksum,
    1
  )
  returning id into v_run_id;

  return jsonb_build_object(
    'status', 'staged',
    'source_id', v_source_id,
    'revision_id', v_revision_id,
    'run_id', v_run_id
  );
end;
$$;

create or replace function public.append_legal_ingestion_batch(
  p_revision_id bigint,
  p_provisions jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_revision_status text;
  v_provision jsonb;
  v_chunk jsonb;
  v_provision_id bigint;
  v_categories text[];
  v_sectors text[];
  v_embedding extensions.vector(768);
begin
  if jsonb_typeof(p_provisions) <> 'array'
    or jsonb_array_length(p_provisions) = 0
  then
    raise exception 'Invalid legal provision batch.';
  end if;

  select r.status
  into v_revision_status
  from rag.legal_revisions r
  where r.id = p_revision_id
  for update;

  if v_revision_status is distinct from 'staged' then
    raise exception 'Legal revision is not staged.';
  end if;

  for v_provision in
    select item.value
    from jsonb_array_elements(p_provisions) as item(value)
  loop
    if nullif(btrim(v_provision->>'provision_code'), '') is null
      or nullif(btrim(v_provision->>'hierarchy_path'), '') is null
      or nullif(btrim(v_provision->>'normalized_text'), '') is null
      or (v_provision->>'content_checksum') !~ '^[a-f0-9]{64}$'
      or jsonb_typeof(v_provision->'categories') <> 'array'
      or jsonb_array_length(v_provision->'categories') = 0
      or jsonb_typeof(v_provision->'chunks') <> 'array'
      or jsonb_array_length(v_provision->'chunks') = 0
    then
      raise exception 'Invalid legal provision batch.';
    end if;

    if exists (
      select 1
      from jsonb_array_elements_text(v_provision->'categories') category(value)
      where category.value not in ('charge', 'fine', 'subscription', 'product', 'bill')
    ) then
      raise exception 'Invalid legal provision category.';
    end if;

    select array_agg(category.value order by category.ordinality)
    into v_categories
    from jsonb_array_elements_text(v_provision->'categories')
      with ordinality as category(value, ordinality);

    select coalesce(array_agg(sector.value order by sector.ordinality), '{}'::text[])
    into v_sectors
    from jsonb_array_elements_text(
      coalesce(v_provision->'sectors', '[]'::jsonb)
    ) with ordinality as sector(value, ordinality);

    insert into rag.legal_provisions (
      revision_id,
      provision_code,
      heading,
      hierarchy_path,
      normalized_text,
      source_anchor,
      categories,
      sectors,
      content_checksum
    )
    values (
      p_revision_id,
      btrim(v_provision->>'provision_code'),
      nullif(btrim(v_provision->>'heading'), ''),
      btrim(v_provision->>'hierarchy_path'),
      v_provision->>'normalized_text',
      nullif(btrim(v_provision->>'source_anchor'), ''),
      v_categories,
      v_sectors,
      v_provision->>'content_checksum'
    )
    on conflict (revision_id, provision_code) do update
    set heading = excluded.heading,
        hierarchy_path = excluded.hierarchy_path,
        normalized_text = excluded.normalized_text,
        source_anchor = excluded.source_anchor,
        categories = excluded.categories,
        sectors = excluded.sectors,
        content_checksum = excluded.content_checksum
    returning id into v_provision_id;

    delete from rag.legal_chunks c
    where c.provision_id = v_provision_id;

    for v_chunk in
      select item.value
      from jsonb_array_elements(v_provision->'chunks') as item(value)
    loop
      if jsonb_typeof(v_chunk->'embedding') <> 'array'
        or jsonb_array_length(v_chunk->'embedding') <> 768
        or exists (
          select 1
          from jsonb_array_elements(v_chunk->'embedding') component(value)
          where jsonb_typeof(component.value) <> 'number'
        )
        or coalesce((v_chunk->>'sequence_no')::integer, -1) < 0
        or coalesce((v_chunk->>'token_count')::integer, 0) <= 0
        or nullif(btrim(v_chunk->>'content'), '') is null
        or nullif(btrim(v_chunk->>'context_heading'), '') is null
        or nullif(btrim(v_chunk->>'embedding_model'), '') is null
        or nullif(btrim(v_chunk->>'embedding_version'), '') is null
      then
        raise exception 'Invalid legal chunk.';
      end if;

      v_embedding := (v_chunk->'embedding')::text::extensions.vector;

      insert into rag.legal_chunks (
        provision_id,
        sequence_no,
        content,
        context_heading,
        token_count,
        embedding,
        embedding_model,
        embedding_version,
        metadata
      )
      values (
        v_provision_id,
        (v_chunk->>'sequence_no')::integer,
        v_chunk->>'content',
        v_chunk->>'context_heading',
        (v_chunk->>'token_count')::integer,
        v_embedding,
        v_chunk->>'embedding_model',
        v_chunk->>'embedding_version',
        coalesce(v_chunk->'metadata', '{}'::jsonb)
      );
    end loop;
  end loop;

  return jsonb_build_object(
    'status', 'staged',
    'revision_id', p_revision_id,
    'provision_count', (
      select count(*) from rag.legal_provisions p where p.revision_id = p_revision_id
    ),
    'chunk_count', (
      select count(*)
      from rag.legal_chunks c
      join rag.legal_provisions p on p.id = c.provision_id
      where p.revision_id = p_revision_id
    )
  );
end;
$$;

create or replace function public.finalize_legal_ingestion(
  p_revision_id bigint,
  p_expected_provision_count integer,
  p_expected_chunk_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_id bigint;
  v_status text;
  v_provision_count integer;
  v_chunk_count integer;
begin
  select r.source_id, r.status
  into v_source_id, v_status
  from rag.legal_revisions r
  where r.id = p_revision_id
  for update;

  if v_status is distinct from 'staged' then
    raise exception 'Legal revision is not staged.';
  end if;

  select count(*)::integer
  into v_provision_count
  from rag.legal_provisions p
  where p.revision_id = p_revision_id;

  select count(*)::integer
  into v_chunk_count
  from rag.legal_chunks c
  join rag.legal_provisions p on p.id = c.provision_id
  where p.revision_id = p_revision_id;

  if p_expected_provision_count <= 0
    or p_expected_chunk_count <= 0
    or v_provision_count <> p_expected_provision_count
    or v_chunk_count <> p_expected_chunk_count
    or exists (
      select 1
      from rag.legal_provisions p
      where p.revision_id = p_revision_id
        and not exists (
          select 1 from rag.legal_chunks c where c.provision_id = p.id
        )
    )
    or exists (
      select 1
      from rag.legal_chunks c
      join rag.legal_provisions p on p.id = c.provision_id
      where p.revision_id = p_revision_id
        and extensions.vector_dims(c.embedding) <> 768
    )
  then
    raise exception 'Legal ingestion validation failed: count or structure mismatch.';
  end if;

  update rag.legal_revisions r
  set status = 'superseded'
  where r.source_id = v_source_id
    and r.status = 'active'
    and r.id <> p_revision_id;

  update rag.legal_revisions r
  set status = 'active'
  where r.id = p_revision_id;

  update rag.ingestion_runs run
  set finished_at = now(),
      status = 'succeeded',
      provision_count = v_provision_count,
      chunk_count = v_chunk_count,
      validation_errors = '[]'::jsonb
  where run.revision_id = p_revision_id
    and run.status = 'running';

  return jsonb_build_object(
    'status', 'active',
    'revision_id', p_revision_id,
    'provision_count', v_provision_count,
    'chunk_count', v_chunk_count
  );
end;
$$;

create or replace function public.fail_legal_ingestion(
  p_revision_id bigint,
  p_validation_errors jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_provision_count integer;
  v_chunk_count integer;
begin
  if jsonb_typeof(p_validation_errors) <> 'array' then
    raise exception 'Validation errors must be an array.';
  end if;

  select r.status
  into v_status
  from rag.legal_revisions r
  where r.id = p_revision_id
  for update;

  if v_status is null then
    raise exception 'Legal revision does not exist.';
  end if;
  if v_status = 'active' then
    raise exception 'Active legal revision cannot be failed.';
  end if;

  select count(*)::integer
  into v_provision_count
  from rag.legal_provisions p
  where p.revision_id = p_revision_id;

  select count(*)::integer
  into v_chunk_count
  from rag.legal_chunks c
  join rag.legal_provisions p on p.id = c.provision_id
  where p.revision_id = p_revision_id;

  update rag.legal_revisions r
  set status = 'rejected'
  where r.id = p_revision_id
    and r.status in ('staged', 'validated');

  update rag.ingestion_runs run
  set finished_at = now(),
      status = 'failed',
      provision_count = v_provision_count,
      chunk_count = v_chunk_count,
      validation_errors = p_validation_errors
  where run.revision_id = p_revision_id
    and run.status = 'running';

  return jsonb_build_object(
    'status', 'failed',
    'revision_id', p_revision_id,
    'provision_count', v_provision_count,
    'chunk_count', v_chunk_count
  );
end;
$$;

revoke all on function public.start_legal_ingestion(jsonb, jsonb)
  from public, anon, authenticated;
revoke all on function public.append_legal_ingestion_batch(bigint, jsonb)
  from public, anon, authenticated;
revoke all on function public.finalize_legal_ingestion(bigint, integer, integer)
  from public, anon, authenticated;
revoke all on function public.fail_legal_ingestion(bigint, jsonb)
  from public, anon, authenticated;

grant execute on function public.start_legal_ingestion(jsonb, jsonb)
  to service_role;
grant execute on function public.append_legal_ingestion_batch(bigint, jsonb)
  to service_role;
grant execute on function public.finalize_legal_ingestion(bigint, integer, integer)
  to service_role;
grant execute on function public.fail_legal_ingestion(bigint, jsonb)
  to service_role;
