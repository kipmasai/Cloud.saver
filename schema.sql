-- Cloud Saver schema for the existing Supabase project.
-- Run in Supabase Dashboard > SQL Editor as project owner.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  first_name text,
  last_name text,
  phone text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cloud_files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 240),
  storage_path text not null unique,
  mime_type text not null default 'application/octet-stream',
  size_bytes bigint not null default 0 check (size_bytes >= 0),
  category text not null default 'other',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  is_shared boolean not null default false
);
create index if not exists cloud_files_owner_created_idx on public.cloud_files(owner_id, created_at desc);
create index if not exists cloud_files_owner_deleted_idx on public.cloud_files(owner_id, deleted_at);

create table if not exists public.file_shares (
  id uuid primary key default gen_random_uuid(),
  file_id uuid not null references public.cloud_files(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists file_shares_token_idx on public.file_shares(token);
create index if not exists file_shares_owner_file_idx on public.file_shares(owner_id, file_id);

-- Admins are explicitly granted by a project owner. Never let users edit their own role.
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now(),
  granted_by text
);

alter table public.profiles enable row level security;
alter table public.cloud_files enable row level security;
alter table public.file_shares enable row level security;
alter table public.admin_users enable row level security;

-- Profiles: users can read and update only their own profile.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select to authenticated using (auth.uid() = id);
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Files: only owner can read, create, update, or delete metadata.
drop policy if exists "cloud_files_select_own" on public.cloud_files;
create policy "cloud_files_select_own" on public.cloud_files for select to authenticated using (auth.uid() = owner_id);
drop policy if exists "cloud_files_insert_own" on public.cloud_files;
create policy "cloud_files_insert_own" on public.cloud_files for insert to authenticated with check (auth.uid() = owner_id and storage_path like auth.uid()::text || '/%');
drop policy if exists "cloud_files_update_own" on public.cloud_files;
create policy "cloud_files_update_own" on public.cloud_files for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id and storage_path like auth.uid()::text || '/%');
drop policy if exists "cloud_files_delete_own" on public.cloud_files;
create policy "cloud_files_delete_own" on public.cloud_files for delete to authenticated using (auth.uid() = owner_id);

-- Share links are private to the owner in the browser. Public access is mediated by the Edge Function below.
drop policy if exists "file_shares_select_own" on public.file_shares;
create policy "file_shares_select_own" on public.file_shares for select to authenticated using (auth.uid() = owner_id);
drop policy if exists "file_shares_insert_own" on public.file_shares;
create policy "file_shares_insert_own" on public.file_shares for insert to authenticated with check (auth.uid() = owner_id and exists (select 1 from public.cloud_files f where f.id = file_id and f.owner_id = auth.uid() and f.deleted_at is null));
drop policy if exists "file_shares_update_own" on public.file_shares;
create policy "file_shares_update_own" on public.file_shares for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
drop policy if exists "file_shares_delete_own" on public.file_shares;
create policy "file_shares_delete_own" on public.file_shares for delete to authenticated using (auth.uid() = owner_id);

-- Admin list is not readable to ordinary users. Authenticated users can only see their own grant.
drop policy if exists "admin_users_select_self" on public.admin_users;
create policy "admin_users_select_self" on public.admin_users for select to authenticated using (auth.uid() = user_id);

-- Create the profile row at signup without copying any privileged metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, nullif(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_cloud_saver on auth.users;
create trigger on_auth_user_created_cloud_saver after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Storage bucket is private. Set a sensible per-file limit; adjust to your Supabase plan.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cloud-files', 'cloud-files', false, 52428800, null)
on conflict (id) do update set public = false, file_size_limit = 52428800;

-- Storage object paths begin with the authenticated user's UUID.
drop policy if exists "cloud_storage_select_own" on storage.objects;
create policy "cloud_storage_select_own" on storage.objects for select to authenticated using (bucket_id = 'cloud-files' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "cloud_storage_insert_own" on storage.objects;
create policy "cloud_storage_insert_own" on storage.objects for insert to authenticated with check (bucket_id = 'cloud-files' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "cloud_storage_update_own" on storage.objects;
create policy "cloud_storage_update_own" on storage.objects for update to authenticated using (bucket_id = 'cloud-files' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id = 'cloud-files' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "cloud_storage_delete_own" on storage.objects;
create policy "cloud_storage_delete_own" on storage.objects for delete to authenticated using (bucket_id = 'cloud-files' and (storage.foldername(name))[1] = auth.uid()::text);

-- Optional admin grant (run manually after a real user has registered, replacing the UUID):
-- insert into public.admin_users (user_id, granted_by) values ('USER-UUID-HERE', 'project-owner');
