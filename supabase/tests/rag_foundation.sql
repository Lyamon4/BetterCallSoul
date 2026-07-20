begin;

do $$
declare
  search_function oid;
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
end $$;

rollback;
