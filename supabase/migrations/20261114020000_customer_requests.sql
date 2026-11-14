begin;

create table public.khadamat_service_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null default auth.uid() references auth.users (id),
  submission_id uuid not null,
  service_code text not null check (
    service_code in ('ac', 'plumbing', 'electric', 'appliances',
      'carpentry', 'cleaning', 'smarthome', 'pest')
  ),
  district text not null check (char_length(btrim(district)) between 1 and 100),
  address text not null check (char_length(btrim(address)) between 1 and 300),
  description text not null check (char_length(btrim(description)) between 1 and 2000),
  preferred_at timestamptz,
  status text not null default 'submitted'
    check (status in ('submitted', 'booked', 'in_progress', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  unique (customer_id, submission_id)
);

create index khadamat_requests_customer_history
  on public.khadamat_service_requests (customer_id, created_at desc);

alter table public.khadamat_service_requests enable row level security;
revoke all on public.khadamat_service_requests from public, anon, authenticated;
grant select on public.khadamat_service_requests to authenticated;
grant insert (submission_id, service_code, district, address, description, preferred_at)
  on public.khadamat_service_requests to authenticated;

create policy khadamat_requests_read_own on public.khadamat_service_requests
  for select to authenticated using (customer_id = (select auth.uid()));

create policy khadamat_requests_submit_own on public.khadamat_service_requests
  for insert to authenticated
  with check (
    customer_id = (select auth.uid())
    and (preferred_at is null or preferred_at > now())
  );

create function public.khadamat_submit_request(
  p_submission_id uuid,
  p_service_code text,
  p_district text,
  p_address text,
  p_description text,
  p_preferred_at timestamptz default null
) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  existing public.khadamat_service_requests;
  request_id uuid;
begin
  select * into existing
  from public.khadamat_service_requests
  where customer_id = (select auth.uid()) and submission_id = p_submission_id;

  if not found then
    insert into public.khadamat_service_requests (
      submission_id, service_code, district, address, description, preferred_at
    ) values (
      p_submission_id, p_service_code, btrim(p_district), btrim(p_address),
      btrim(p_description), p_preferred_at
    )
    on conflict (customer_id, submission_id) do nothing
    returning id into request_id;

    if found then
      return request_id;
    end if;

    select * into strict existing
    from public.khadamat_service_requests
    where customer_id = (select auth.uid()) and submission_id = p_submission_id;
  end if;

  if (existing.service_code, existing.district, existing.address, existing.description, existing.preferred_at)
     is distinct from (p_service_code, btrim(p_district), btrim(p_address), btrim(p_description), p_preferred_at) then
    raise exception 'Submission identifier already used with different details' using errcode = '23505';
  end if;
  return existing.id;
end;
$$;

revoke all on function public.khadamat_submit_request(uuid, text, text, text, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.khadamat_submit_request(uuid, text, text, text, text, timestamptz)
  to authenticated;

commit;
