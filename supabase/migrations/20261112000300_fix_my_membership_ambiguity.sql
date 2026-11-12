-- RETURNS TABLE names are PL/pgSQL output variables. Qualify table columns
-- to avoid colliding with the status output variable; preserve all checks/ACLs.
begin;

create or replace function public.my_membership()
returns table(status text, verified_kind text, profile_complete boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  if exists (
    select 1 from private.memberships as membership
    where membership.user_id = auth.uid() and membership.status = 'verified'
  ) and not private.is_verified() then
    raise insufficient_privilege using message = 'Confirmed email required';
  end if;

  return query
    select m.status::text, m.verified_kind::text, p.user_id is not null
    from (select auth.uid() as id) as caller
    left join public.profiles as p on p.user_id = caller.id
    left join private.memberships as m on m.user_id = caller.id;
end;
$$;

commit;
