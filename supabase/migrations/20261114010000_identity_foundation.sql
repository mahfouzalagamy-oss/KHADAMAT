begin;

create schema khadamat_private;
revoke all on schema khadamat_private from public, anon, authenticated;
grant usage on schema khadamat_private to service_role;

create table public.khadamat_profiles (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  display_name text not null check (
    char_length(btrim(display_name)) between 1 and 80
    and display_name !~ '[[:cntrl:]]'
  )
);

alter table public.khadamat_profiles enable row level security;
revoke all on public.khadamat_profiles from public, anon, authenticated;
grant select on public.khadamat_profiles to authenticated;
grant insert (display_name), update (display_name)
  on public.khadamat_profiles to authenticated;

create policy khadamat_profiles_read_own on public.khadamat_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy khadamat_profiles_insert_own on public.khadamat_profiles
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy khadamat_profiles_update_own on public.khadamat_profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create table khadamat_private.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('technician', 'platform_admin')),
  primary key (user_id, role)
);

alter table khadamat_private.user_roles enable row level security;
revoke all on khadamat_private.user_roles from public, anon, authenticated;
grant select, insert, delete on khadamat_private.user_roles to service_role;

create function public.khadamat_my_roles()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null then array[]::text[]
    else array['customer']::text[] || array(
      select user_roles.role
      from khadamat_private.user_roles
      where user_roles.user_id = auth.uid()
        and (
          user_roles.role <> 'platform_admin'
          or auth.jwt() ->> 'aal' = 'aal2'
        )
      order by user_roles.role
    )
  end
$$;

revoke all on function public.khadamat_my_roles() from public, anon, authenticated;
grant execute on function public.khadamat_my_roles() to authenticated;

commit;
