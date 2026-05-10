-- Ejecutar en Supabase SQL Editor.
-- Corrige el registro público para tablas public.referees que tienen first_name NOT NULL.
-- Mantiene compatibilidad con columnas anteriores: name / last_name.

create extension if not exists pgcrypto;

create table if not exists public.referees (
    id uuid primary key default gen_random_uuid(),
    first_name text not null default '',
    name text not null default '',
    last_name text not null default '',
    paternal_last_name text not null default '',
    maternal_last_name text not null default '',
    division text not null default 'Primera division',
    category text not null default 'Regular',
    phone text not null default '',
    email text not null default '',
    coach_team text not null default '',
    player_team text not null default '',
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.referees add column if not exists first_name text;
alter table public.referees add column if not exists name text;
alter table public.referees add column if not exists last_name text;
alter table public.referees add column if not exists paternal_last_name text;
alter table public.referees add column if not exists maternal_last_name text;
alter table public.referees add column if not exists division text;
alter table public.referees add column if not exists category text;
alter table public.referees add column if not exists phone text;
alter table public.referees add column if not exists email text;
alter table public.referees add column if not exists coach_team text;
alter table public.referees add column if not exists player_team text;
alter table public.referees add column if not exists active boolean;
alter table public.referees add column if not exists created_at timestamptz;
alter table public.referees add column if not exists updated_at timestamptz;

update public.referees
set first_name = coalesce(nullif(first_name, ''), nullif(name, ''), '')
where first_name is null or btrim(first_name) = '';

update public.referees
set name = coalesce(nullif(name, ''), nullif(first_name, ''), '')
where name is null or btrim(name) = '';

update public.referees
set last_name = coalesce(nullif(last_name, ''), nullif(paternal_last_name, ''), '')
where last_name is null or btrim(last_name) = '';

update public.referees set paternal_last_name = coalesce(paternal_last_name, '') where paternal_last_name is null;
update public.referees set maternal_last_name = coalesce(maternal_last_name, '') where maternal_last_name is null;
update public.referees set division = coalesce(nullif(division, ''), 'Primera division') where division is null or btrim(division) = '';
update public.referees set category = coalesce(nullif(category, ''), 'Regular') where category is null or btrim(category) = '';
update public.referees set phone = coalesce(phone, '') where phone is null;
update public.referees set email = lower(btrim(coalesce(email, ''))) where email is null or email <> lower(btrim(email));
update public.referees set coach_team = coalesce(coach_team, '') where coach_team is null;
update public.referees set player_team = coalesce(player_team, '') where player_team is null;
update public.referees set active = coalesce(active, true) where active is null;
update public.referees set created_at = coalesce(created_at, now()) where created_at is null;
update public.referees set updated_at = coalesce(updated_at, now()) where updated_at is null;

alter table public.referees alter column first_name set default '';
alter table public.referees alter column name set default '';
alter table public.referees alter column last_name set default '';
alter table public.referees alter column paternal_last_name set default '';
alter table public.referees alter column maternal_last_name set default '';
alter table public.referees alter column division set default 'Primera division';
alter table public.referees alter column category set default 'Regular';
alter table public.referees alter column phone set default '';
alter table public.referees alter column email set default '';
alter table public.referees alter column coach_team set default '';
alter table public.referees alter column player_team set default '';
alter table public.referees alter column active set default true;
alter table public.referees alter column created_at set default now();
alter table public.referees alter column updated_at set default now();

alter table public.referees alter column first_name set not null;
alter table public.referees alter column name set not null;
alter table public.referees alter column last_name set not null;
alter table public.referees alter column paternal_last_name set not null;
alter table public.referees alter column maternal_last_name set not null;
alter table public.referees alter column division set not null;
alter table public.referees alter column category set not null;
alter table public.referees alter column phone set not null;
alter table public.referees alter column email set not null;
alter table public.referees alter column coach_team set not null;
alter table public.referees alter column player_team set not null;
alter table public.referees alter column active set not null;
alter table public.referees alter column created_at set not null;
alter table public.referees alter column updated_at set not null;

create unique index if not exists referees_email_lower_uidx
on public.referees (lower(email))
where email is not null and btrim(email) <> '';

create table if not exists public.referee_availability (
    id uuid primary key default gen_random_uuid(),
    referee_id uuid not null references public.referees(id) on delete cascade,
    availability_date date not null,
    participates boolean not null default true,
    available_from time without time zone,
    available_to time without time zone,
    unavailable_blocks jsonb not null default '[]'::jsonb,
    notes text,
    submitted_at timestamptz not null default now(),
    unique (referee_id, availability_date)
);

alter table public.schedule_matches add column if not exists referee_id uuid null references public.referees(id) on delete set null;
alter table public.schedule_matches add column if not exists referee_name text null;

create or replace function public.submit_referee_registration_public(
    p_name text,
    p_last_name text,
    p_division text,
    p_category text,
    p_phone text,
    p_email text,
    p_coach_team text default null,
    p_player_team text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_email text := lower(btrim(coalesce(p_email, '')));
    v_first_name text := btrim(coalesce(p_name, ''));
    v_last_name text := btrim(coalesce(p_last_name, ''));
    v_id uuid;
begin
    if v_first_name = '' or v_email = '' then
        return jsonb_build_object('ok', false, 'message', 'Nombre y correo son obligatorios.');
    end if;

    select id into v_id
    from public.referees
    where lower(email) = v_email
    limit 1;

    if v_id is null then
        insert into public.referees (
            first_name,
            name,
            last_name,
            paternal_last_name,
            maternal_last_name,
            division,
            category,
            phone,
            email,
            coach_team,
            player_team,
            active,
            created_at,
            updated_at
        ) values (
            v_first_name,
            v_first_name,
            v_last_name,
            v_last_name,
            '',
            btrim(coalesce(p_division, 'Primera division')),
            btrim(coalesce(p_category, 'Regular')),
            btrim(coalesce(p_phone, '')),
            v_email,
            coalesce(nullif(btrim(coalesce(p_coach_team, '')), ''), ''),
            coalesce(nullif(btrim(coalesce(p_player_team, '')), ''), ''),
            true,
            now(),
            now()
        ) returning id into v_id;
    else
        update public.referees
        set first_name = v_first_name,
            name = v_first_name,
            last_name = v_last_name,
            paternal_last_name = v_last_name,
            maternal_last_name = coalesce(maternal_last_name, ''),
            division = btrim(coalesce(p_division, 'Primera division')),
            category = btrim(coalesce(p_category, 'Regular')),
            phone = btrim(coalesce(p_phone, '')),
            email = v_email,
            coach_team = coalesce(nullif(btrim(coalesce(p_coach_team, '')), ''), ''),
            player_team = coalesce(nullif(btrim(coalesce(p_player_team, '')), ''), ''),
            active = true,
            updated_at = now()
        where id = v_id;
    end if;

    return jsonb_build_object('ok', true, 'message', 'Árbitro registrado correctamente.', 'referee_id', v_id);
end;
$$;

create or replace function public.submit_referee_availability_public(
    p_email text,
    p_availability_date date,
    p_participates boolean,
    p_available_from time without time zone,
    p_available_to time without time zone,
    p_unavailable_blocks jsonb default '[]'::jsonb,
    p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_email text := lower(btrim(coalesce(p_email, '')));
    v_referee_id uuid;
begin
    select id into v_referee_id
    from public.referees
    where lower(email) = v_email
      and active = true
    limit 1;

    if v_referee_id is null then
        return jsonb_build_object('ok', false, 'message', 'No existe un árbitro activo con ese correo. Primero debe registrarse en el catálogo.');
    end if;

    insert into public.referee_availability (
        referee_id, availability_date, participates, available_from, available_to,
        unavailable_blocks, notes, submitted_at
    ) values (
        v_referee_id, p_availability_date, coalesce(p_participates, true),
        p_available_from, p_available_to, coalesce(p_unavailable_blocks, '[]'::jsonb),
        nullif(btrim(coalesce(p_notes, '')), ''), now()
    )
    on conflict (referee_id, availability_date)
    do update set
        participates = excluded.participates,
        available_from = excluded.available_from,
        available_to = excluded.available_to,
        unavailable_blocks = excluded.unavailable_blocks,
        notes = excluded.notes,
        submitted_at = now();

    return jsonb_build_object('ok', true, 'message', 'Disponibilidad registrada correctamente.');
end;
$$;

grant execute on function public.submit_referee_registration_public(text, text, text, text, text, text, text, text) to anon, authenticated;
grant execute on function public.submit_referee_availability_public(text, date, boolean, time without time zone, time without time zone, jsonb, text) to anon, authenticated;

grant select on public.referees to anon, authenticated;
grant select on public.referee_availability to anon, authenticated;

notify pgrst, 'reload schema';
