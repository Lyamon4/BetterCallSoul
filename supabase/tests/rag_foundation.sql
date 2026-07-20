begin;

do $$
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
end $$;

rollback;
