create extension if not exists pgcrypto;

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  tenant_key text not null unique,
  name text not null,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

insert into public.tenants (tenant_key, name)
values ('inova-ti', 'Inova TI')
on conflict (tenant_key) do nothing;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  email text not null,
  name text not null,
  role text not null default 'developer',
  created_at timestamptz not null default now(),
  unique (tenant_id, email)
);

create table if not exists public.tenant_secrets (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  secret_name text not null,
  encrypted_value bytea not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, secret_name)
);

create table if not exists public.project_memory (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  project text not null,
  memory_type text not null,
  content jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.users enable row level security;
alter table public.tenant_secrets enable row level security;
alter table public.project_memory enable row level security;

drop policy if exists tenant_isolation_users on public.users;
create policy tenant_isolation_users on public.users using (tenant_id::text = current_setting('app.tenant_id', true));

drop policy if exists tenant_isolation_project_memory on public.project_memory;
create policy tenant_isolation_project_memory on public.project_memory using (tenant_id::text = current_setting('app.tenant_id', true));

drop policy if exists tenant_isolation_tenant_secrets on public.tenant_secrets;
create policy tenant_isolation_tenant_secrets on public.tenant_secrets using (tenant_id::text = current_setting('app.tenant_id', true));

-- Role de aplicacao (nao-superuser) para RLS efetivo em producao.
do $$
begin
  if not exists (select from pg_roles where rolname = 'inova_app') then
    create role inova_app login password 'inova_app_password_change_me';
  end if;
end
$$;

grant usage on schema public to inova_app;
grant select, insert, update, delete on public.users to inova_app;
grant select, insert, update, delete on public.tenant_secrets to inova_app;
grant select, insert, update, delete on public.project_memory to inova_app;
grant select on public.tenants to inova_app;
