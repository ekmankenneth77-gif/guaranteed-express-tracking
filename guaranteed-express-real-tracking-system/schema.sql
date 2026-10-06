-- Guaranteed Express Delivery Services
-- Supabase/Postgres schema.
-- Run this in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.admin_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.shipments (
  id uuid primary key default gen_random_uuid(),
  tracking_number text not null unique,
  status text not null default 'IN TRANSIT',
  estimated_delivery date,
  service text not null default 'Express Delivery',
  weight text,
  origin text,
  destination text,
  sender_name text,
  recipient_name text,
  package_type text,
  reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tracking_events (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  status text not null,
  message text,
  location text,
  event_time timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists shipments_tracking_number_idx on public.shipments (tracking_number);
create index if not exists tracking_events_shipment_idx on public.tracking_events (shipment_id, event_time desc);

alter table public.admin_profiles enable row level security;
alter table public.shipments enable row level security;
alter table public.tracking_events enable row level security;

revoke all on public.admin_profiles from anon, authenticated;
revoke all on public.shipments from anon, authenticated;
revoke all on public.tracking_events from anon, authenticated;

grant select on public.admin_profiles to authenticated;
grant select, insert, update, delete on public.shipments to authenticated;
grant select, insert, update, delete on public.tracking_events to authenticated;

drop policy if exists "admins read own profile" on public.admin_profiles;
create policy "admins read own profile"
on public.admin_profiles for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "admins manage shipments" on public.shipments;
create policy "admins manage shipments"
on public.shipments for all to authenticated
using (exists (select 1 from public.admin_profiles p where p.user_id=(select auth.uid())))
with check (exists (select 1 from public.admin_profiles p where p.user_id=(select auth.uid())));

drop policy if exists "admins manage tracking events" on public.tracking_events;
create policy "admins manage tracking events"
on public.tracking_events for all to authenticated
using (exists (select 1 from public.admin_profiles p where p.user_id=(select auth.uid())))
with check (exists (select 1 from public.admin_profiles p where p.user_id=(select auth.uid())));

-- Public tracking RPC. It returns only customer-safe fields and only for an exact
-- tracking number; the underlying tables remain inaccessible to anon.
create or replace function public.track_shipment(p_tracking_number text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce((
    select jsonb_build_object(
      'tracking_number', s.tracking_number,
      'status', s.status,
      'estimated_delivery', s.estimated_delivery,
      'service', s.service,
      'weight', s.weight,
      'origin', s.origin,
      'destination', s.destination,
      'sender_name', s.sender_name,
      'recipient_name', s.recipient_name,
      'package_type', s.package_type,
      'reference', s.reference,
      'events', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'status', e.status,
            'message', e.message,
            'location', e.location,
            'event_time', e.event_time
          ) order by e.event_time desc
        ) from public.tracking_events e where e.shipment_id=s.id
      ), '[]'::jsonb)
    )
    from public.shipments s
    where upper(s.tracking_number)=upper(trim(p_tracking_number))
  ), '{}'::jsonb);
$$;

revoke all on function public.track_shipment(text) from public;
grant execute on function public.track_shipment(text) to anon, authenticated;

-- Automatic updated_at.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end; $$;

drop trigger if exists shipments_updated_at on public.shipments;
create trigger shipments_updated_at before update on public.shipments
for each row execute function public.set_updated_at();

-- After creating your first Supabase Auth user, run:
-- insert into public.admin_profiles(user_id) values ('PASTE_AUTH_USER_UUID_HERE');
