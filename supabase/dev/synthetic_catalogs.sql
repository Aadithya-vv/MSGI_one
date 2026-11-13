-- SYNTHETIC LOCAL ONLY. Never included by config.toml/official seed.sql.
-- Run only on the isolated port-55322 database. Repeated inserts preserve data.
begin;
do $$ begin
 if current_setting('msgi.synthetic_local',true) is distinct from 'yes' then
   raise exception 'Explicit isolated-local fixture opt-in required';
 end if;
end $$;
insert into public.institutions(id,name) values
 ('40000000-0000-4000-8000-000000000001','[SYNTHETIC LOCAL] Example Institute'),
 ('40000000-0000-4000-8000-000000000002','[SYNTHETIC LOCAL] Example College') on conflict do nothing;
insert into public.departments(id,institution_id,name) values
 ('41000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','[SYNTHETIC LOCAL] Computing'),
 ('41000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000002','[SYNTHETIC LOCAL] Design') on conflict do nothing;
insert into public.skills(id,name) values
 ('42000000-0000-4000-8000-000000000001','[SYNTHETIC LOCAL] Programming'),
 ('42000000-0000-4000-8000-000000000002','[SYNTHETIC LOCAL] Research') on conflict do nothing;
insert into public.cities(id,name,country_code) values
 ('43000000-0000-4000-8000-000000000001','[SYNTHETIC LOCAL] Example City','IN') on conflict do nothing;
commit;
