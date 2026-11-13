begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000000001', 'customer-one@example.invalid', '{"role":"platform_admin"}'),
  ('00000000-0000-4000-8000-000000000002', 'customer-two@example.invalid', '{}');

insert into public.khadamat_profiles (user_id, display_name) values
  ('00000000-0000-4000-8000-000000000002', 'Customer Two');

set local role anon;
select throws_ok('select * from public.khadamat_profiles', '42501', null, 'Anonymous users cannot read profiles');
select throws_ok('select public.khadamat_my_roles()', '42501', null, 'Anonymous users cannot query roles');

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-000000000001","aal":"aal1"}';

select is(public.khadamat_my_roles(), array['customer']::text[], 'User metadata cannot grant an elevated role');
select lives_ok($$insert into public.khadamat_profiles (display_name) values ('Customer One')$$, 'Customer can create own profile');
select results_eq(
  'select display_name from public.khadamat_profiles',
  $$values ('Customer One'::text)$$,
  'Customer only sees their own profile'
);
select is_empty(
  $$with changed as (
    update public.khadamat_profiles set display_name = 'Changed'
    where user_id = '00000000-0000-4000-8000-000000000002' returning user_id
  ) select user_id from changed$$,
  'Customer cannot update another profile'
);
select throws_ok(
  $$insert into public.khadamat_profiles (user_id, display_name) values ('00000000-0000-4000-8000-000000000002', 'Imposter')$$,
  '42501', null, 'Customer cannot supply a different owner'
);
select throws_ok(
  $$insert into khadamat_private.user_roles values ('00000000-0000-4000-8000-000000000001', 'technician')$$,
  '42501', null, 'Customer cannot assign a role'
);
select lives_ok($$update public.khadamat_profiles set display_name = 'Updated Name'$$, 'Customer can update their own name');

reset role;
set local role service_role;
insert into khadamat_private.user_roles values
  ('00000000-0000-4000-8000-000000000001', 'technician'),
  ('00000000-0000-4000-8000-000000000001', 'platform_admin');
reset role;
set local role authenticated;
select is(public.khadamat_my_roles(), array['customer','technician']::text[], 'AAL1 sees approved technician role but cannot act as admin');
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-000000000001","aal":"aal2"}';
select is(public.khadamat_my_roles(), array['customer','platform_admin','technician']::text[], 'AAL2 unlocks an assigned admin role');

reset role;
delete from khadamat_private.user_roles where role = 'platform_admin';
set local role authenticated;
select is(public.khadamat_my_roles(), array['customer','technician']::text[], 'Role revocation takes effect with the current token');

reset role;
select * from finish();
rollback;
