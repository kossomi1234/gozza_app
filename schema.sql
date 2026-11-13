-- Gozza database. Run the whole file once in Supabase > SQL Editor.
-- Row-level security (RLS) is ON for every table. Users can only reach what the rules allow.

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  role text not null default 'client' check (role in ('client','driver','manager','employee','owner')),
  status text not null default 'pending' check (status in ('pending','active','suspended','rejected')),
  full_name text, phone text, whatsapp text,
  state text, district text, village text, neighborhood text, zip text,
  online boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.vehicles (
  id serial primary key, service text not null, name text not null,
  base int not null check (base >= 0), per_km int not null check (per_km >= 0),
  enabled boolean not null default true
);
create table public.trips (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles,
  driver_id uuid references public.profiles,
  vehicle_id int not null references public.vehicles,
  pickup text not null, dropoff text not null,
  km_est numeric not null default 4.2,
  fare int,
  status text not null default 'requested' check (status in ('requested','accepted','completed','cancelled')),
  created_at timestamptz not null default now()
);
create table public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.profiles on delete cascade,
  doc_type text not null check (doc_type in ('license','passport','id','birth_certificate','photo','vehicle_registration','insurance','vehicle_photo','police_clearance')),
  file_path text not null,
  created_at timestamptz not null default now(),
  unique (driver_id, doc_type)
);

-- helpers
create function public.is_owner() returns boolean language sql security definer stable set search_path = public as
$$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'owner' and status = 'active') $$;
create function public.is_active_driver() returns boolean language sql security definer stable set search_path = public as
$$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'driver' and status = 'active') $$;

-- new clients start active, new drivers start pending (owner approves). Owner is set by hand (see README).
create function public.profiles_defaults() returns trigger language plpgsql security definer set search_path = public as
$$ begin
  if auth.uid() is not null then new.status := case when new.role = 'client' then 'active' else 'pending' end; end if;
  return new;
end $$;
create trigger profiles_defaults before insert on public.profiles for each row execute function public.profiles_defaults();

-- the fare is always calculated here, never trusted from the app
create function public.set_fare() returns trigger language plpgsql security definer set search_path = public as
$$ declare v public.vehicles;
begin
  select * into v from public.vehicles where id = new.vehicle_id and enabled;
  if not found then raise exception 'vehicle not available'; end if;
  new.fare := round((v.base + v.per_km * new.km_est) / 50) * 50;
  return new;
end $$;
create trigger trips_fare before insert on public.trips for each row execute function public.set_fare();

-- owner-only way to approve, suspend or change a role
create function public.owner_set_profile(target uuid, new_status text, new_role text default null) returns void
language plpgsql security definer set search_path = public as
$$ begin
  if not public.is_owner() then raise exception 'owner only'; end if;
  update public.profiles set status = new_status, role = coalesce(new_role, role) where id = target;
end $$;

-- lock everything, then open only what is needed
revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from anon;
grant select, insert on public.profiles to authenticated;
grant update (full_name, whatsapp, state, district, village, neighborhood, zip, online) on public.profiles to authenticated;
grant select on public.vehicles to authenticated;
grant update (base, per_km, enabled) on public.vehicles to authenticated;   -- RLS below lets only the owner do it
grant select, insert on public.trips to authenticated;
grant update (driver_id, status) on public.trips to authenticated;
grant select, insert on public.driver_documents to authenticated;
grant usage on all sequences in schema public to authenticated;

alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.trips enable row level security;
alter table public.driver_documents enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (id = auth.uid() or public.is_owner());
create policy profiles_create on public.profiles for insert to authenticated with check (id = auth.uid() and role in ('client','driver'));
create policy profiles_edit_own on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy vehicles_read on public.vehicles for select to authenticated using (enabled or public.is_owner());
create policy vehicles_owner_edit on public.vehicles for update to authenticated using (public.is_owner()) with check (public.is_owner());

create policy trips_client_read on public.trips for select to authenticated using (client_id = auth.uid());
create policy trips_client_create on public.trips for insert to authenticated with check (client_id = auth.uid() and driver_id is null and status = 'requested');
create policy trips_driver_read on public.trips for select to authenticated using (public.is_active_driver() and (status = 'requested' or driver_id = auth.uid()));
create policy trips_driver_accept on public.trips for update to authenticated using (public.is_active_driver() and status = 'requested') with check (driver_id = auth.uid() and status = 'accepted');
create policy trips_driver_finish on public.trips for update to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid() and status in ('accepted','completed'));
create policy trips_owner_read on public.trips for select to authenticated using (public.is_owner());

create policy docs_read on public.driver_documents for select to authenticated using (driver_id = auth.uid() or public.is_owner());
create policy docs_create on public.driver_documents for insert to authenticated with check (driver_id = auth.uid());

-- private storage for driver and client documents (folder name = user id)
insert into storage.buckets (id, name, public) values ('documents', 'documents', false) on conflict (id) do nothing;
create policy documents_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and (storage.foldername(name))[1] = auth.uid()::text);
create policy documents_read on storage.objects for select to authenticated
  using (bucket_id = 'documents' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_owner()));

-- starting vehicles (prices are placeholders, FCFA)
insert into public.vehicles (service, name, base, per_km) values
 ('moto','Motorcycle',300,150), ('rickshaw','Tuk-tuk (tricycle)',400,180),
 ('car','Toyota Corolla',800,300), ('car','Land Cruiser 4x4',1200,400),
 ('taxi','Taxi',700,250), ('taxi','Hiace minibus (shared)',300,100),
 ('package','Small package (under 2 kg)',500,100), ('package','Medium package (2 to 10 kg)',800,150), ('package','Large package (10 to 25 kg)',1200,250),
 ('food','Food delivery',500,100),
 ('goods','Cart (charrette)',800,200), ('goods','Cargo tricycle',1500,300), ('goods','Toyota Hilux pickup',3000,500), ('goods','Toyota Hiace van',4500,700), ('goods','Lorry (10 t)',9000,1200);
