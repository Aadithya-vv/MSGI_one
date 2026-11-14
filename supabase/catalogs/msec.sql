-- Reviewed Task 11A MSEC catalog. Application UUIDs/keys are not official codes.
-- Owner-reviewed operation, not an automatically invoked public seed.
begin;
do $$ begin
 if current_setting('msgi.catalog_approved',true) is distinct from 'msec-task11a-local' then
   raise exception 'Explicit reviewed MSEC catalog approval required';
 end if;
 if exists(select 1 from public.institutions i where i.id='a1100000-0000-4000-8000-000000000001' and i.catalog_key is distinct from 'msec') then
   raise exception 'Application UUID conflicts with an existing institution; stop for review';
 end if;
end; $$;
insert into public.institutions(id,name,catalog_key) values
 ('a1100000-0000-4000-8000-000000000001','Meenakshi Sundararajan Engineering College (MSEC)','msec')
on conflict(catalog_key) do update set name=excluded.name;
insert into public.departments(id,institution_id,name)
 select 'a1120000-0000-4000-8000-000000000001',i.id,'Science and Humanities'
 from public.institutions i where i.catalog_key='msec'
on conflict(id) do nothing;
insert into public.programmes(id,institution_id,application_key,name,level)
select v.id::uuid,i.id,v.application_key,v.name,v.level from public.institutions i cross join (values
 ('a1110000-0000-4000-8000-000000000001','msec-ug-ai-ds','B.Tech. Artificial Intelligence & Data Science','undergraduate'),
 ('a1110000-0000-4000-8000-000000000002','msec-ug-ai-ml','B.Tech. Artificial Intelligence & Machine Learning','undergraduate'),
 ('a1110000-0000-4000-8000-000000000003','msec-ug-civil','B.E. Civil Engineering','undergraduate'),
 ('a1110000-0000-4000-8000-000000000004','msec-ug-cse','B.E. Computer Science and Engineering','undergraduate'),
 ('a1110000-0000-4000-8000-000000000005','msec-ug-cse-cybersecurity','B.E. Computer Science & Engineering (Cybersecurity)','undergraduate'),
 ('a1110000-0000-4000-8000-000000000006','msec-ug-eee','B.E. Electrical and Electronics Engineering','undergraduate'),
 ('a1110000-0000-4000-8000-000000000007','msec-ug-ece','B.E. Electronics and Communication Engineering','undergraduate'),
 ('a1110000-0000-4000-8000-000000000008','msec-ug-it','B.Tech. Information Technology','undergraduate'),
 ('a1110000-0000-4000-8000-000000000009','msec-ug-mechanical','B.E. Mechanical Engineering','undergraduate'),
 ('a1110000-0000-4000-8000-000000000010','msec-pg-cs','M.E. Computer Science','postgraduate'),
 ('a1110000-0000-4000-8000-000000000011','msec-pg-construction','M.E. Construction Engineering and Management','postgraduate'),
 ('a1110000-0000-4000-8000-000000000012','msec-pg-embedded','M.E. Embedded Systems and Technologies','postgraduate'),
 ('a1110000-0000-4000-8000-000000000013','msec-pg-energy','M.E. Energy Engineering','postgraduate')) v(id,application_key,name,level) where i.catalog_key='msec'
on conflict(application_key) do update set name=excluded.name,level=excluded.level
 where programmes.institution_id=excluded.institution_id;
do $$ begin
 if (select count(*) from public.programmes p join public.institutions i on i.id=p.institution_id where i.catalog_key='msec' and p.application_key like 'msec-%')<>13
 or not exists(select 1 from public.departments d join public.institutions i on i.id=d.institution_id where i.catalog_key='msec' and d.id='a1120000-0000-4000-8000-000000000001' and d.name='Science and Humanities') then
   raise exception 'Catalog conflicts or unexpected count; transaction rolled back';
 end if;
end; $$;
commit;
