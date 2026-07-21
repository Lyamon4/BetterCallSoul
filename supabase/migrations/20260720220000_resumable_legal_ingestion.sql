alter table rag.ingestion_runs
  drop constraint if exists ingestion_runs_status_check;

alter table rag.ingestion_runs
  add constraint ingestion_runs_status_check check (
    status in ('running', 'paused', 'succeeded', 'failed', 'unchanged')
  );

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
  v_resumable_revision_id bigint;
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
      'run_id', v_run_id,
      'provision_count', (
        select count(*)
        from rag.legal_provisions p
        where p.revision_id = v_active_revision_id
      ),
      'chunk_count', (
        select count(*)
        from rag.legal_chunks c
        join rag.legal_provisions p on p.id = c.provision_id
        where p.revision_id = v_active_revision_id
      )
    );
  end if;

  select r.id
  into v_resumable_revision_id
  from rag.legal_revisions r
  where r.source_id = v_source_id
    and r.revision_code = v_revision_code
    and r.content_checksum = v_content_checksum
    and r.parser_version = v_parser_version
    and r.status = 'staged'
    and not exists (
      select 1
      from rag.legal_chunks c
      join rag.legal_provisions p on p.id = c.provision_id
      where p.revision_id = r.id
        and c.embedding_model <> v_embedding_model
    )
  limit 1
  for update;

  if v_resumable_revision_id is not null then
    update rag.ingestion_runs run
    set finished_at = now(),
        status = 'paused',
        validation_errors = jsonb_build_array(
          jsonb_build_object('code', 'interrupted_before_resume')
        )
    where run.revision_id = v_resumable_revision_id
      and run.status = 'running';

    insert into rag.ingestion_runs (
      source_id,
      revision_id,
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
      v_resumable_revision_id,
      'running',
      v_parser_version,
      v_embedding_model,
      v_content_checksum,
      0,
      (
        select count(*)
        from rag.legal_provisions p
        where p.revision_id = v_resumable_revision_id
      ),
      (
        select count(*)
        from rag.legal_chunks c
        join rag.legal_provisions p on p.id = c.provision_id
        where p.revision_id = v_resumable_revision_id
      )
    )
    returning id into v_run_id;

    return jsonb_build_object(
      'status', 'resuming',
      'source_id', v_source_id,
      'revision_id', v_resumable_revision_id,
      'run_id', v_run_id,
      'completed_provision_codes', coalesce(
        (
          select jsonb_agg(p.provision_code order by p.provision_code)
          from rag.legal_provisions p
          where p.revision_id = v_resumable_revision_id
            and exists (
              select 1
              from rag.legal_chunks c
              where c.provision_id = p.id
            )
        ),
        '[]'::jsonb
      )
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
    'run_id', v_run_id,
    'completed_provision_codes', '[]'::jsonb
  );
end;
$$;

create or replace function public.pause_legal_ingestion(
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

  update rag.ingestion_runs run
  set finished_at = now(),
      status = 'paused',
      provision_count = v_provision_count,
      chunk_count = v_chunk_count,
      validation_errors = p_validation_errors
  where run.revision_id = p_revision_id
    and run.status = 'running';

  return jsonb_build_object(
    'status', 'paused',
    'revision_id', p_revision_id,
    'provision_count', v_provision_count,
    'chunk_count', v_chunk_count
  );
end;
$$;

revoke all on function public.pause_legal_ingestion(bigint, jsonb)
  from public, anon, authenticated;

grant execute on function public.pause_legal_ingestion(bigint, jsonb)
  to service_role;
