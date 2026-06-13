create table if not exists public.worker_audit_log (
  id bigserial primary key,
  tenant_id text not null,
  project text not null,
  worker text not null,
  event_type text not null,
  correlation_id text not null,
  status text not null,
  payload jsonb not null default '{}'::jsonb,
  error text,
  created_at timestamptz not null default now()
);

create index if not exists idx_worker_audit_correlation on public.worker_audit_log(correlation_id);
create index if not exists idx_worker_audit_tenant_created on public.worker_audit_log(tenant_id, created_at desc);

grant select, insert, update, delete on public.worker_audit_log to inova_app;

create table if not exists public.dead_letter_events (
  id bigserial primary key,
  tenant_id text not null,
  project text not null,
  event_type text not null,
  correlation_id text not null,
  payload jsonb not null,
  error text not null,
  created_at timestamptz not null default now()
);

grant select, insert, update, delete on public.dead_letter_events to inova_app;
