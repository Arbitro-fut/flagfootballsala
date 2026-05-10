-- Ejecutar una sola vez en Supabase SQL Editor.
-- Habilita registro público de árbitros, registro público de disponibilidad
-- y columnas para que la app guarde el árbitro asignado en schedule_matches.

create extension if not exists pgcrypto;

create table if not exists public.referees (
    id uuid primary key default gen_random_uuid(),
    name text,
    last_name text,
    division text,
    category text default 'Regular',
    phone text,
    email text,
    coach_team text,
    player_team text,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.referees add column if not exists name text;
alter table public.referees add column if not exists last_name text;
alter table public.referees add column if not exists division text;
alter table public.referees add column if not exists category text default 'Regular';
alter table public.referees add column if not exists phone text;
alter table public.referees add column if not exists email text;
alter table public.referees add column if not exists coach_team text;
alter table public.referees add column if not exists player_team text;
alter table public.referees add column if not exists active boolean not null default true;
alter table public.referees add column if not exists created_at timestamptz not null default now();
alter table public.referees add column if not exists updated_at timestamptz not null default now();

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
    v_id uuid;
begin
    if btrim(coalesce(p_name, '')) = '' or v_email = '' then
        return jsonb_build_object('ok', false, 'message', 'Nombre y correo son obligatorios.');
    end if;

    select id into v_id
    from public.referees
    where lower(email) = v_email
    limit 1;

    if v_id is null then
        insert into public.referees (
            name, last_name, division, category, phone, email, coach_team, player_team, active, created_at, updated_at
        ) values (
            btrim(p_name), btrim(coalesce(p_last_name, '')), btrim(coalesce(p_division, '')),
            btrim(coalesce(p_category, 'Regular')), btrim(coalesce(p_phone, '')), v_email,
            nullif(btrim(coalesce(p_coach_team, '')), ''),
            nullif(btrim(coalesce(p_player_team, '')), ''),
            true, now(), now()
        ) returning id into v_id;
    else
        update public.referees
        set name = btrim(p_name),
            last_name = btrim(coalesce(p_last_name, '')),
            division = btrim(coalesce(p_division, '')),
            category = btrim(coalesce(p_category, 'Regular')),
            phone = btrim(coalesce(p_phone, '')),
            coach_team = nullif(btrim(coalesce(p_coach_team, '')), ''),
            player_team = nullif(btrim(coalesce(p_player_team, '')), ''),
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
