begin;

do $$
declare
  search_function oid;
  ingestion_function oid;
  private_table regclass;
begin
  assert exists (select 1 from pg_extension where extname = 'vector'),
    'vector extension is required';
  assert to_regclass('rag.legal_chunks') is not null,
    'rag.legal_chunks is required';
  assert to_regclass('public.cases') is not null,
    'public.cases is required';
  assert (
    select relrowsecurity
    from pg_class
    where oid = 'public.cases'::regclass
  ), 'public.cases must have RLS';

  search_function := to_regprocedure(
    'public.search_legal_chunks(text,extensions.vector,text,date,integer)'
  );
  assert search_function is not null,
    'public.search_legal_chunks is required';
  assert not has_function_privilege('anon', search_function, 'execute'),
    'anon must not execute public.search_legal_chunks';
  assert not has_function_privilege('authenticated', search_function, 'execute'),
    'authenticated must not execute public.search_legal_chunks';
  assert has_function_privilege('service_role', search_function, 'execute'),
    'service_role must execute public.search_legal_chunks';
  assert (
    select p.prosecdef
    from pg_proc p
    where p.oid = search_function
  ), 'public.search_legal_chunks must be security definer';
  assert (
    select coalesce(p.proconfig, '{}'::text[]) @> array['search_path=""']
    from pg_proc p
    where p.oid = search_function
  ), 'public.search_legal_chunks must fix an empty search_path';

  foreach private_table in array array[
    'rag.legal_sources'::regclass,
    'rag.legal_revisions'::regclass,
    'rag.legal_provisions'::regclass,
    'rag.legal_chunks'::regclass,
    'rag.ingestion_runs'::regclass
  ] loop
    assert (
      select relrowsecurity from pg_class where oid = private_table
    ), format('%s must have RLS enabled', private_table);
  end loop;

  foreach ingestion_function in array array[
    to_regprocedure('public.start_legal_ingestion(jsonb,jsonb)'),
    to_regprocedure('public.append_legal_ingestion_batch(bigint,jsonb)'),
    to_regprocedure('public.finalize_legal_ingestion(bigint,integer,integer)'),
    to_regprocedure('public.pause_legal_ingestion(bigint,jsonb)'),
    to_regprocedure('public.fail_legal_ingestion(bigint,jsonb)')
  ] loop
    assert ingestion_function is not null,
      'all legal ingestion functions are required';
    assert not has_function_privilege('anon', ingestion_function, 'execute'),
      'anon must not execute legal ingestion functions';
    assert not has_function_privilege('authenticated', ingestion_function, 'execute'),
      'authenticated must not execute legal ingestion functions';
    assert has_function_privilege('service_role', ingestion_function, 'execute'),
      'service_role must execute legal ingestion functions';
    assert (
      select p.prosecdef from pg_proc p where p.oid = ingestion_function
    ), 'legal ingestion functions must be security definer';
    assert (
      select coalesce(p.proconfig, '{}'::text[]) @> array['search_path=""']
      from pg_proc p
      where p.oid = ingestion_function
    ), 'legal ingestion functions must fix an empty search_path';
  end loop;
end $$;

do $$
declare
  start_result jsonb;
  unchanged_result jsonb;
  paused_result jsonb;
  failed_result jsonb;
  revision_id bigint;
begin
  start_result := public.start_legal_ingestion(
    jsonb_build_object(
      'source_code', 'test_ingestion_source',
      'title', 'Test official source',
      'authority', 'Republic of Kazakhstan',
      'official_url', 'https://adilet.zan.kz/rus/docs/TEST_INGESTION',
      'jurisdiction', 'KZ',
      'language', 'ru',
      'document_type', 'law',
      'adopted_on', '2026-01-01'
    ),
    jsonb_build_object(
      'revision_code', 'sha256:test-revision-1',
      'effective_from', '2026-01-01',
      'content_checksum', repeat('a', 64),
      'parser_version', 'test-parser-v1',
      'normalized_text', 'Статья 1. Проверочное правило.',
      'embedding_model', 'gemini-embedding-2'
    )
  );
  assert start_result->>'status' = 'staged', 'new revision must be staged';
  revision_id := (start_result->>'revision_id')::bigint;

  perform public.append_legal_ingestion_batch(
    revision_id,
    jsonb_build_array(
      jsonb_build_object(
        'provision_code', 'article:1',
        'heading', 'Статья 1',
        'hierarchy_path', 'Глава 1',
        'normalized_text', 'Проверочное правило.',
        'source_anchor', '#z1',
        'categories', jsonb_build_array('product'),
        'sectors', jsonb_build_array('consumer'),
        'content_checksum', repeat('b', 64),
        'chunks', jsonb_build_array(
          jsonb_build_object(
            'sequence_no', 0,
            'content', 'Проверочное правило.',
            'context_heading', 'Test official source — Статья 1',
            'token_count', 5,
            'embedding', to_jsonb(array_fill(0.01::double precision, array[768])),
            'embedding_model', 'gemini-embedding-2',
            'embedding_version', 'gemini-embedding-2',
            'metadata', '{}'::jsonb
          )
        )
      )
    )
  );

  begin
    perform public.finalize_legal_ingestion(revision_id, 2, 1);
    assert false, 'count mismatch must fail activation';
  exception when others then
    assert sqlerrm like 'Legal ingestion validation failed:%';
  end;
  assert (
    select status = 'staged'
    from rag.legal_revisions
    where id = revision_id
  ), 'failed validation must keep the revision staged';

  perform public.finalize_legal_ingestion(revision_id, 1, 1);
  assert (
    select status = 'active'
    from rag.legal_revisions
    where id = revision_id
  ), 'validated revision must become active';

  unchanged_result := public.start_legal_ingestion(
    jsonb_build_object(
      'source_code', 'test_ingestion_source',
      'title', 'Test official source',
      'authority', 'Republic of Kazakhstan',
      'official_url', 'https://adilet.zan.kz/rus/docs/TEST_INGESTION',
      'jurisdiction', 'KZ',
      'language', 'ru',
      'document_type', 'law'
    ),
    jsonb_build_object(
      'revision_code', 'sha256:test-revision-1',
      'effective_from', '2026-01-01',
      'content_checksum', repeat('a', 64),
      'parser_version', 'test-parser-v1',
      'normalized_text', 'Статья 1. Проверочное правило.',
      'embedding_model', 'gemini-embedding-2'
    )
  );
  assert unchanged_result->>'status' = 'unchanged',
    'matching active checksum must skip ingestion';

  paused_result := public.start_legal_ingestion(
    jsonb_build_object(
      'source_code', 'test_ingestion_source',
      'title', 'Test official source',
      'authority', 'Republic of Kazakhstan',
      'official_url', 'https://adilet.zan.kz/rus/docs/TEST_INGESTION',
      'jurisdiction', 'KZ',
      'language', 'ru',
      'document_type', 'law'
    ),
    jsonb_build_object(
      'revision_code', 'sha256:test-revision-2',
      'effective_from', '2026-07-20',
      'content_checksum', repeat('c', 64),
      'parser_version', 'test-parser-v1',
      'normalized_text', 'Статья 1. Новая версия.',
      'embedding_model', 'gemini-embedding-2'
    )
  );
  perform public.append_legal_ingestion_batch(
    (paused_result->>'revision_id')::bigint,
    jsonb_build_array(
      jsonb_build_object(
        'provision_code', 'article:2',
        'heading', 'Статья 2',
        'hierarchy_path', 'Глава 1',
        'normalized_text', 'Новая версия правила.',
        'source_anchor', '#z2',
        'categories', jsonb_build_array('product'),
        'sectors', jsonb_build_array('consumer'),
        'content_checksum', repeat('d', 64),
        'chunks', jsonb_build_array(
          jsonb_build_object(
            'sequence_no', 0,
            'content', 'Новая версия правила.',
            'context_heading', 'Test official source — Статья 2',
            'token_count', 5,
            'embedding', to_jsonb(array_fill(0.02::double precision, array[768])),
            'embedding_model', 'gemini-embedding-2',
            'embedding_version', 'gemini-embedding-2',
            'metadata', '{}'::jsonb
          )
        )
      )
    )
  );
  perform public.pause_legal_ingestion(
    (paused_result->>'revision_id')::bigint,
    jsonb_build_array(jsonb_build_object('code', 'embedding_quota_exhausted'))
  );
  assert (
    select status = 'staged'
    from rag.legal_revisions
    where id = (paused_result->>'revision_id')::bigint
  ), 'paused ingestion must keep the revision staged';
  assert (
    select count(*) = 1
    from rag.ingestion_runs run
    where run.revision_id = (paused_result->>'revision_id')::bigint
      and run.status = 'paused'
  ), 'paused ingestion must close the current run';

  failed_result := public.start_legal_ingestion(
    jsonb_build_object(
      'source_code', 'test_ingestion_source',
      'title', 'Test official source',
      'authority', 'Republic of Kazakhstan',
      'official_url', 'https://adilet.zan.kz/rus/docs/TEST_INGESTION',
      'jurisdiction', 'KZ',
      'language', 'ru',
      'document_type', 'law'
    ),
    jsonb_build_object(
      'revision_code', 'sha256:test-revision-2',
      'effective_from', '2026-07-20',
      'content_checksum', repeat('c', 64),
      'parser_version', 'test-parser-v1',
      'normalized_text', 'Статья 1. Новая версия.',
      'embedding_model', 'gemini-embedding-2'
    )
  );
  assert failed_result->>'status' = 'resuming',
    'matching staged revision must resume';
  assert failed_result->'completed_provision_codes' = jsonb_build_array('article:2'),
    'resume must return completed provisions';
  perform public.fail_legal_ingestion(
    (failed_result->>'revision_id')::bigint,
    jsonb_build_array('test failure')
  );
  assert (
    select status = 'active'
    from rag.legal_revisions
    where id = revision_id
  ), 'failed refresh must preserve the last active revision';
end $$;

rollback;
