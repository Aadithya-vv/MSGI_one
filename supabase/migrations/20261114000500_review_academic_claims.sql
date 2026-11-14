-- Review-only projection; no role provisioning and no changes to approval grants.
begin;
create function public.pending_memberships_v2(p_limit integer default 30)
returns table(user_id uuid,display_name text,claimed_kind text,institution_id uuid,
 department_id uuid,joining_year integer,graduation_year integer,programme_id uuid,
 programme text,institution text,department text,affiliation text)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_limit is null or p_limit not between 1 and 100 then raise check_violation; end if;
 return query select p.user_id,p.display_name,p.claimed_kind::text,p.institution_id,p.department_id,
 p.joining_year::integer,p.graduation_year::integer,p.programme_id,pr.name,i.name,d.name,p.affiliation
 from public.profiles p join private.memberships m on m.user_id=p.user_id
 join public.institutions i on i.id=p.institution_id
 left join public.departments d on d.id=p.department_id
 left join public.programmes pr on pr.id=p.programme_id
 where m.status='pending' order by p.created_at,p.user_id limit p_limit;
end; $$;
revoke all on function public.pending_memberships_v2(integer) from public,anon,authenticated;
grant execute on function public.pending_memberships_v2(integer) to authenticated;
notify pgrst,'reload schema';
commit;
