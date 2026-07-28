-- =====================================================================
--  GRAFIK KOMORY NORMOBARYCZNEJ — baza danych
--  Wklej CAŁOŚĆ do Supabase → SQL Editor → Run. Jeden raz.
-- =====================================================================

create extension if not exists pgcrypto;

-- od maja 2026 nowe projekty Supabase wymagają jawnych uprawnień do schematu
grant usage on schema public to anon;

-- ---------------------------------------------------------------------
-- 1. Tabela rezerwacji. Widzi ją WYŁĄCZNIE właściciel (Ty, w panelu).
-- ---------------------------------------------------------------------
create table if not exists rezerwacje (
  id        uuid primary key default gen_random_uuid(),
  slot      timestamptz not null,
  imie      text        not null,
  telefon   text        not null,
  osoby     smallint    not null default 1,
  uwagi     text,
  kod       text        not null,
  odwolana  boolean     not null default false,
  utworzono timestamptz not null default now()
);

create index if not exists rezerwacje_slot_idx on rezerwacje (slot);
create index if not exists rezerwacje_kod_idx  on rezerwacje (kod);

-- Włączamy ochronę wierszy i NIE dodajemy żadnej polityki dla anon.
-- Efekt: przeglądarka klienta nie ma jak dosięgnąć tej tabeli.
alter table rezerwacje enable row level security;

revoke all on table rezerwacje from anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. Widok publiczny — jedyne, co wychodzi na świat.
--    Godzina + liczba zajętych miejsc. Zero nazwisk, zero telefonów.
-- ---------------------------------------------------------------------
create or replace view zajetosc as
  select slot, sum(osoby)::int as zajete
  from rezerwacje
  where odwolana = false
  group by slot;

alter view zajetosc set (security_invoker = off);
grant select on zajetosc to anon;

-- ---------------------------------------------------------------------
-- 3. Rezerwacja — jedyna droga zapisu. Blokada + przeliczenie miejsc.
--    UWAGA: pojemność komory ustaw w v_pojemnosc (i tak samo w index.html).
-- ---------------------------------------------------------------------
create or replace function zarezerwuj(
  p_slot    timestamptz,
  p_imie    text,
  p_telefon text,
  p_osoby   int,
  p_uwagi   text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pojemnosc int := 4;   -- <<< MIEJSCA W KOMORZE
  v_zajete    int;
  v_ile_ma    int;
  v_kod       text;
begin
  if p_slot is null or p_slot < now() then
    raise exception 'Ten termin już minął. Wybierz inny.';
  end if;
  if p_slot > now() + interval '90 days' then
    raise exception 'Za daleko w przyszłość.';
  end if;
  if p_osoby < 1 or p_osoby > v_pojemnosc then
    raise exception 'Nieprawidłowa liczba osób.';
  end if;
  if length(btrim(coalesce(p_imie,''))) < 2 then
    raise exception 'Podaj imię i nazwisko.';
  end if;
  if length(regexp_replace(coalesce(p_telefon,''), '\D', '', 'g')) < 9 then
    raise exception 'Podaj numer telefonu (9 cyfr).';
  end if;

  -- zapora na zasypanie grafiku przez jedną osobę
  select count(*) into v_ile_ma
  from rezerwacje
  where regexp_replace(telefon, '\D', '', 'g') = regexp_replace(p_telefon, '\D', '', 'g')
    and odwolana = false
    and slot > now();
  if v_ile_ma >= 5 then
    raise exception 'Masz już 5 aktywnych rezerwacji. Odwołaj którąś albo zadzwoń.';
  end if;

  -- zamek na tę jedną godzinę: dwie osoby klikające naraz staną w kolejce
  perform pg_advisory_xact_lock(hashtext(p_slot::text));

  select coalesce(sum(osoby), 0) into v_zajete
  from rezerwacje
  where slot = p_slot and odwolana = false;

  if v_zajete + p_osoby > v_pojemnosc then
    raise exception 'Ktoś Cię ubiegł — w tej godzinie nie ma już tylu miejsc.';
  end if;

  v_kod := upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6));

  insert into rezerwacje (slot, imie, telefon, osoby, uwagi, kod)
  values (p_slot, btrim(p_imie), btrim(p_telefon), p_osoby, nullif(btrim(p_uwagi), ''), v_kod);

  return json_build_object('kod', v_kod, 'slot', p_slot, 'osoby', p_osoby);
end $$;

grant execute on function zarezerwuj(timestamptz, text, text, int, text) to anon;

-- ---------------------------------------------------------------------
-- 4. Odwołanie rezerwacji kodem z potwierdzenia.
-- ---------------------------------------------------------------------
create or replace function odwolaj(p_kod text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slot timestamptz;
begin
  update rezerwacje
     set odwolana = true
   where upper(btrim(kod)) = upper(btrim(coalesce(p_kod, '')))
     and odwolana = false
     and slot > now()
  returning slot into v_slot;

  if v_slot is null then
    raise exception 'Nie znaleziono aktywnej rezerwacji o tym kodzie.';
  end if;

  return json_build_object('slot', v_slot);
end $$;

grant execute on function odwolaj(text) to anon;
