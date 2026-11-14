select jsonb_build_object(
 'read_only',current_setting('transaction_read_only'),
 'tables',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,'rows',
 ((xpath('//row/count/text()',query_to_xml(format('select count(*) from %I.%I',n.nspname,c.relname),false,true,'')))[1]::text)::bigint)
 order by n.nspname,c.relname)
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where c.relkind='r' and n.nspname in ('public','private','auth','storage','supabase_migrations')),
 'extensions',(select jsonb_agg(jsonb_build_object('name',e.extname,'version',e.extversion,'schema',n.nspname))
 from pg_extension e join pg_namespace n on n.oid=e.extnamespace),
 'version',current_setting('server_version')) as inventory;
