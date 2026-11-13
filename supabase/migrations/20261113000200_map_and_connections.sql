-- Task 05: isolated-local first. Explicit approval required before hosted deployment.
begin;
-- Approved city centroids only, quantized to ~11km latitude; never user coordinates.
alter table public.cities add column centroid_latitude numeric(4,1), add column centroid_longitude numeric(5,1),
 add constraint city_centroid_pair check((centroid_latitude is null)=(centroid_longitude is null)),
 add constraint city_centroid_bounds check(centroid_latitude between -85 and 85 and centroid_longitude between -180 and 180);
create index profiles_map_city_idx on public.profiles(city_id,user_id) where map_opt_in and directory_visible;

create function public.alumni_city_clusters(p_location text default '',p_domain text default '',p_after uuid default null,p_limit integer default 101)
returns table(city_id uuid,city text,country_code text,latitude numeric,longitude numeric,alumni_count bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_location is null or p_domain is null or char_length(p_location)>100 or char_length(p_domain)>120 or p_limit is null or p_limit not between 1 and 201 then raise check_violation; end if;
 return query select c.id,c.name,c.country_code,c.centroid_latitude,c.centroid_longitude,count(*)
 from public.profiles p join private.memberships m on m.user_id=p.user_id
 join public.institutions i on i.id=p.institution_id and i.active
 join public.departments d on d.id=p.department_id and d.active
 join public.cities c on c.id=p.city_id and c.centroid_latitude is not null
 where m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
 and p.directory_visible and p.map_opt_in
 and (p_after is null or c.id>p_after)
 and (btrim(p_location)='' or position(lower(btrim(p_location)) in lower(c.name||' '||c.country_code))>0)
 and (btrim(p_domain)='' or position(lower(btrim(p_domain)) in lower(p.professional_domain))>0)
 group by c.id order by c.id limit p_limit;
end; $$;
create function public.map_city_members(p_city uuid,p_domain text default '',p_after uuid default null,p_limit integer default 21)
returns table(user_id uuid,display_name text,institution text,department text,graduation_year integer,designation text,company text,professional_domain text,skills text[])
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_domain is null or char_length(p_domain)>120 or p_city is null or p_limit is null or p_limit not between 1 and 51 then raise check_violation; end if;
 return query select p.user_id,p.display_name,i.name,d.name,p.graduation_year::integer,p.designation,p.company,p.professional_domain,
 coalesce((select array_agg(s.name order by s.name) from public.profile_skills ps join public.skills s on s.id=ps.skill_id where ps.profile_id=p.user_id),'{}'::text[])
 from public.profiles p join private.memberships m on m.user_id=p.user_id
 join public.institutions i on i.id=p.institution_id and i.active
 join public.departments d on d.id=p.department_id and d.active
 join public.cities c on c.id=p.city_id and c.centroid_latitude is not null
 where p.city_id=p_city and m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
 and p.directory_visible and p.map_opt_in and (p_after is null or p.user_id>p_after)
 and (btrim(p_domain)='' or position(lower(btrim(p_domain)) in lower(p.professional_domain))>0)
 order by p.user_id limit p_limit;
end; $$;

create function public.request_connection(p_recipient uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); existing public.connections;
begin
 if not private.is_verified() or not private.member_verified(p_recipient) or not exists(select 1 from public.profiles p where p.user_id=p_recipient and p.directory_visible) then raise insufficient_privilege; end if;
 if actor=p_recipient then raise check_violation; end if;
 perform pg_advisory_xact_lock(hashtextextended(least(actor,p_recipient)::text||greatest(actor,p_recipient)::text,0));
 select c.* into existing from public.connections c where c.user_low=least(actor,p_recipient) and c.user_high=greatest(actor,p_recipient) for update;
 if found then
  if existing.status in ('pending','accepted') then return existing.id; end if;
  if existing.status='rejected' then raise check_violation using message='Previous request declined'; end if;
  update public.connections set sender_id=actor,recipient_id=p_recipient,status='pending',updated_at=now() where id=existing.id;
  return existing.id;
 end if;
 insert into public.connections(sender_id,recipient_id) values(actor,p_recipient)
 on conflict(user_low,user_high) do nothing returning * into existing;
 if existing.id is null then
  select c.* into strict existing from public.connections c where c.user_low=least(actor,p_recipient) and c.user_high=greatest(actor,p_recipient);
 end if;
 return existing.id;
end; $$;
create function public.manage_connection(p_id uuid,p_action text) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); relation public.connections;
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_action is null or p_action not in ('accepted','rejected','cancelled','removed') then raise check_violation; end if;
 select c.* into strict relation from public.connections c where c.id=p_id for update;
 if actor not in (relation.sender_id,relation.recipient_id) then raise insufficient_privilege; end if;
 if (p_action in ('accepted','rejected') and actor<>relation.recipient_id) or (p_action='cancelled' and actor<>relation.sender_id) then raise insufficient_privilege; end if;
 if p_action='accepted' and (not private.member_verified(relation.sender_id) or not private.member_verified(relation.recipient_id)) then raise insufficient_privilege; end if;
 if (p_action=relation.status::text) or (p_action='removed' and relation.status='cancelled') then return; end if;
 if (p_action='removed' and relation.status<>'accepted') or (p_action<>'removed' and relation.status<>'pending') then raise check_violation; end if;
 update public.connections set status=case when p_action='removed' then 'cancelled'::public.connection_status else p_action::public.connection_status end,updated_at=now() where id=p_id;
end; $$;
create function public.network_connections(p_tab text default 'accepted',p_after uuid default null,p_limit integer default 21,p_peer uuid default null)
returns table(connection_id uuid,peer_id uuid,display_name text,company text,status text,incoming boolean,profile_available boolean,peer_eligible boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_tab is null or p_tab not in ('incoming','outgoing','accepted','all') or p_limit is null or p_limit not between 1 and 51 then raise check_violation; end if;
 return query select c.id,p.user_id,
 case when private.member_verified(p.user_id) and p.directory_visible then p.display_name end,
 case when private.member_verified(p.user_id) and p.directory_visible then p.company end,
 c.status::text,c.recipient_id=auth.uid(),private.member_verified(p.user_id) and p.directory_visible and exists(select 1 from private.memberships pm join public.institutions pi on pi.id=p.institution_id and pi.active join public.departments pd on pd.id=p.department_id and pd.active where pm.user_id=p.user_id and pm.verified_kind='alumni'),private.member_verified(p.user_id)
 from public.connections c join public.profiles p on p.user_id=case when c.sender_id=auth.uid() then c.recipient_id else c.sender_id end
 where auth.uid() in(c.sender_id,c.recipient_id) and (p_after is null or c.id>p_after) and (p_peer is null or p.user_id=p_peer)
 and (p_tab='all' or (p_tab='accepted' and c.status='accepted') or (p_tab='incoming' and c.status='pending' and c.recipient_id=auth.uid()) or (p_tab='outgoing' and c.status='pending' and c.sender_id=auth.uid()))
 order by c.id limit p_limit;
end; $$;
revoke all on function public.alumni_city_clusters(text,text,uuid,integer),public.map_city_members(uuid,text,uuid,integer),public.request_connection(uuid),public.manage_connection(uuid,text),public.network_connections(text,uuid,integer,uuid) from public,anon,authenticated;
grant execute on function public.alumni_city_clusters(text,text,uuid,integer),public.map_city_members(uuid,text,uuid,integer),public.request_connection(uuid),public.manage_connection(uuid,text),public.network_connections(text,uuid,integer,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
