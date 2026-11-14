begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000101', 'first-requester@example.invalid'),
  ('00000000-0000-4000-8000-000000000102', 'second-requester@example.invalid');

set local role anon;
select throws_ok('select * from public.khadamat_service_requests', '42501', null, 'Anonymous users cannot read requests');
select throws_ok(
  $$select public.khadamat_submit_request('00000000-0000-4000-8000-000000000103', 'ac', 'District', 'Street', 'Description')$$,
  '42501', null, 'Anonymous users cannot submit requests'
);

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-4000-8000-000000000101';
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-000000000101","aal":"aal1"}';

select lives_ok(
  $$select public.khadamat_submit_request('00000000-0000-4000-8000-000000000103', 'ac', ' District ', 'Street', 'Description')$$,
  'Customer can submit a request'
);
select is(
  public.khadamat_submit_request('00000000-0000-4000-8000-000000000103', 'ac', 'District', 'Street', 'Description'),
  (select id from public.khadamat_service_requests),
  'A retry returns the original request identifier'
);
select is((select count(*) from public.khadamat_service_requests), 1::bigint, 'A retry creates only one row');
select throws_ok(
  $$select public.khadamat_submit_request('00000000-0000-4000-8000-000000000103', 'ac', 'District', 'Other street', 'Description')$$,
  '23505', null, 'Reusing a submission ID with different details is rejected'
);
select throws_ok(
  $$select public.khadamat_submit_request('00000000-0000-4000-8000-000000000104', 'ac', 'District', 'Street', 'Description', now() - interval '1 day')$$,
  '42501', null, 'A past appointment is rejected'
);
select throws_ok(
  $$update public.khadamat_service_requests set status = 'completed'$$,
  '42501', null, 'Customers cannot change the request workflow status directly'
);
select throws_ok(
  $$insert into public.khadamat_service_requests (customer_id, submission_id, service_code, district, address, description)
    values ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000104', 'ac', 'District', 'Street', 'Description')$$,
  '42501', null, 'Customers cannot assign another customer as owner'
);

set local request.jwt.claim.sub = '00000000-0000-4000-8000-000000000102';
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-000000000102","aal":"aal1"}';
select is_empty('select id from public.khadamat_service_requests', 'Another customer sees no requests belonging to the first account');
select lives_ok(
  $$select public.khadamat_submit_request('00000000-0000-4000-8000-000000000103', 'plumbing', 'District', 'Street', 'Other description')$$,
  'Submission IDs are scoped to the authenticated customer'
);

reset role;
select * from finish();
rollback;
