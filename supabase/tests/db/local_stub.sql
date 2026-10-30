-- Minimal stand-in for the Supabase pieces the migrations rely on, so the schema and RLS test
-- can run on a plain Postgres (CI, cloud sessions without Docker). Not used on the real project.

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role supabase_auth_admin nologin;

create schema auth;
create schema extensions;

create table auth.users (
  id uuid primary key,
  aud text,
  role text,
  email text
);

create function auth.uid() returns uuid
  language sql stable
  as $$ select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid $$;

grant usage on schema auth, public, extensions to anon, authenticated, service_role, supabase_auth_admin;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Same default grants the Supabase platform gives objects created in public
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
