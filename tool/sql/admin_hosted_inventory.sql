-- Aggregate-only, read-only review. No user records, email addresses or secrets.
select jsonb_build_object(
 'read_only',current_setting('transaction_read_only'),
 'database',current_database(),'version',current_setting('server_version'),
 'ssl',(select ssl from pg_stat_ssl where pid=pg_backend_pid()),
 'tls_version',(select version from pg_stat_ssl where pid=pg_backend_pid()),
 'history',(select jsonb_agg(version order by version) from supabase_migrations.schema_migrations),
 'history_columns',(select jsonb_agg(jsonb_build_object('name',column_name,'type',data_type,'nullable',is_nullable,'default',column_default) order by ordinal_position) from information_schema.columns where table_schema='supabase_migrations' and table_name='schema_migrations'),
 'roles',jsonb_build_object('count',(select count(*) from private.account_roles),
 'without_profile',(select count(*) from private.account_roles r left join public.profiles p on p.user_id=r.user_id where p.user_id is null),
 'inactive_or_missing_institution',(select count(*) from private.account_roles r join public.profiles p on p.user_id=r.user_id left join public.institutions i on i.id=p.institution_id where i.id is null or not i.active)),
 'auth_users_count',(select count(*) from auth.users),
 'default_acls',(select jsonb_agg(jsonb_build_object('owner',pg_get_userbyid(d.defaclrole),'schema',n.nspname,'object_type',d.defaclobjtype,'acl',d.defaclacl) order by n.nspname,d.defaclobjtype) from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace where n.nspname in ('public','private')),
 'tables',(select jsonb_agg(jsonb_build_object('schema',s.nspname,'table',s.relname,'rows',((xpath('//row/count/text()',s.x))[1]::text)::bigint,
 'digest',(xpath('//row/digest/text()',s.x))[1]::text) order by s.nspname,s.relname)
 from (select n.nspname,c.relname,query_to_xml(format('select count(*) as count,md5(coalesce(string_agg(md5(row_to_json(v)::text),'''' order by md5(row_to_json(v)::text)),'''')) as digest from %I.%I v',n.nspname,c.relname),false,true,'') x
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname in ('public','private'))s),
 'functions',(select jsonb_agg(jsonb_build_object('name',n.nspname||'.'||p.proname,'arguments',pg_get_function_identity_arguments(p.oid),'result',pg_get_function_result(p.oid),'body_hash',md5(p.prosrc),'security_definer',p.prosecdef,'config',p.proconfig,'acl',p.proacl) order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private')),
 'tables_security',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'name',c.relname,'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'acl',c.relacl) order by n.nspname,c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname in ('public','private')),
 'policies',(select jsonb_agg(to_jsonb(p) order by schemaname,tablename,policyname) from pg_policies p where schemaname in ('public','private')),
 'indexes',(select jsonb_agg(to_jsonb(i) order by schemaname,indexname) from pg_indexes i where schemaname in ('public','private')),
 'triggers',(select jsonb_agg(jsonb_build_object('table',t.tgrelid::regclass::text,'name',t.tgname,'definition',pg_get_triggerdef(t.oid)) order by t.tgrelid::regclass::text,t.tgname) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal and n.nspname in ('public','private')),
 'constraints',(select jsonb_agg(jsonb_build_object('table',k.conrelid::regclass::text,'name',k.conname,'validated',k.convalidated,'definition',pg_get_constraintdef(k.oid)) order by n.nspname,k.conname) from pg_constraint k join pg_namespace n on n.oid=k.connamespace where n.nspname in ('public','private')),
 'active_ddl',(select count(*) from pg_stat_activity where pid<>pg_backend_pid() and state='active' and backend_type='client backend' and query ~* '^\s*(alter|create|drop|truncate|reindex)'),
 'waiting_locks',(select count(*) from pg_locks where not granted)
) as inventory;
