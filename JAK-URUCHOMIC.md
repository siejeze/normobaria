# Grafik komory normobarycznej — uruchomienie

Trzy pliki, dwa darmowe konta, około 30 minut. Nic tu nie wymaga karty płatniczej.

---

## 1. Baza danych (Supabase) — 10 minut

1. Wejdź na **supabase.com**, załóż konto (logowanie przez GitHub jest najszybsze).
2. **New project**. Nazwa dowolna, region: **Frankfurt (eu-central-1)** — najbliżej Polski, dane zostają w UE.
3. Zapisz hasło do bazy, które wymyślisz. Przyda się raz na ruski rok, ale bez niego nie ma odzysku.
4. Poczekaj, aż projekt się postawi (2–3 minuty).
5. Lewe menu → **SQL Editor** → **New query**. Wklej **całą** zawartość `baza.sql` i naciśnij **Run**.
   Powinno napisać „Success. No rows returned".
6. Lewe menu → **Project Settings** → **API**. Potrzebujesz dwóch rzeczy:
   - **Project URL** (wygląda jak `https://abcdefgh.supabase.co`)
   - klucz **anon / public** (długi ciąg znaków)

> **Klucz `anon` jest jawny** — siedzi w kodzie strony i każdy może go zobaczyć. Tak ma być.
> Dlatego cała ochrona siedzi w bazie: klucz pozwala *tylko* zapytać o liczbę zajętych miejsc,
> zapisać się i odwołać kod. Nie pozwala odczytać ani jednego nazwiska.
> Klucza **service_role** nigdy nie wklejaj do strony. Nigdzie. Nawet na chwilę.

---

## 2. Ustawienia apki — 5 minut

Otwórz `index.html` w dowolnym edytorze tekstu. Na dole, w bloku `const CONFIG`, wpisz swoje:

```js
SUPABASE_URL: "https://twoj-projekt.supabase.co",
SUPABASE_KEY: "wklejony-klucz-anon",
pojemnosc:    4,     // ile osób wchodzi naraz do komory
dlugoscMin:   75,
cisnienie:    "1,5 ATA",
godziny: { 1: ["09:00","10:45", ...], ... }   // 0 = niedziela, 1 = poniedziałek
wolne: ["2026-08-15"],   // dni zamknięte
```

**Uwaga na jedną rzecz:** liczba miejsc występuje w dwóch plikach. Jeśli zmienisz `pojemnosc`
w `index.html`, zmień też `v_pojemnosc` w funkcji `zarezerwuj` w bazie (SQL Editor → wklej
poprawioną funkcję jeszcze raz). Strona pilnuje wyglądu, baza pilnuje prawdy — muszą się zgadzać.

---

## 3. Strona (GitHub Pages) — 10 minut

Tak samo jak przy „Co Cię boli":

1. Nowe repozytorium, np. `normobaria`, publiczne.
2. Wrzuć do niego `index.html` (i tylko jego — reszta plików to Twoje zaplecze).
3. **Settings** → **Pages** → Source: `Deploy from a branch`, gałąź `main`, katalog `/ (root)`.
4. Po minucie strona żyje pod `https://twojanazwa.github.io/normobaria/`.

Chcesz ładniejszy adres, np. `zapisy.twojadomena.pl`? Domena to jedyny koszt w całym
przedsięwzięciu (kilkadziesiąt złotych rocznie), a GitHub Pages podepnie ją za darmo,
razem z certyfikatem HTTPS.

---

## 4. Instalacja na telefonie klienta

Strona jest aplikacją progresywną (PWA), więc nie trzeba jej wrzucać do żadnego sklepu:

- **Android / Chrome** — po chwili od wejścia na dole wyskakuje pasek „Zapisz apkę na telefonie”
  z przyciskiem. Jedno kliknięcie i ikona ląduje na ekranie, bez paska adresu, jak zwykła apka.
- **iPhone / Safari** — Apple nie pozwala na automatyczny monit, więc apka wyświetla instrukcję:
  Udostępnij → „Dodaj do ekranu początkowego”. Ten pasek daje się zamknąć krzyżykiem i wtedy
  już nie wraca.
- **Komputer** — w pasku adresu Chrome pojawia się ikonka instalacji.

Po zainstalowaniu apka otwiera się natychmiast nawet przy słabym zasięgu, bo wygląd siedzi
w pamięci telefonu. **Wolne terminy nigdy nie są zapamiętywane** — to celowe. Gdyby były,
klient w windzie zobaczyłby wczorajszy grafik i zapisał się na zajętą godzinę. Bez internetu
apka mówi wprost, że nie zna aktualnych terminów.

Repozytorium ma wyglądać tak:

```
normobaria/
├── index.html
├── manifest.webmanifest
├── sw.js
├── ikony/
│   ├── ikona-192.png
│   ├── ikona-512.png
│   ├── ikona-maskable-512.png
│   └── apple-touch-icon.png
└── .github/workflows/budzik.yml
```

Ikony możesz podmienić na własne — wystarczy zachować nazwy i rozmiary. Ta „maskable”
musi mieć rysunek w środkowej części kwadratu, bo Android przycina ją do koła albo kwiatka,
zależnie od telefonu.

Zmieniasz coś w plikach? Podnieś numer w `sw.js`, w linii `const WERSJA = "normobaria-v1"`,
na `-v2`. Bez tego telefony z zainstalowaną apką będą uparcie pokazywać starą wersję.

---

## 5. Gdzie Ty widzisz nazwiska

Supabase → **Table Editor** → tabela `rezerwacje`. Działa też na telefonie, w przeglądarce.
Sortuj po kolumnie `slot`, a zobaczysz grafik dnia z imionami, telefonami i uwagami.
Rezerwacje odwołane nie znikają — mają `odwolana = true`, więc masz ślad.

Jeśli po tygodniu okaże się, że zaglądanie do panelu Supabase jest męczące, zrobię Ci osobną
stronę-kokpit z logowaniem na Twój e-mail. To dodatkowe pół godziny, nie więcej.

---

## 6. Pułapka darmowego planu — przeczytaj, zanim się zdziwisz

Supabase usypia darmowe projekty po tygodniu bez ruchu. Przy działającym gabinecie to się nie zdarzy —
każde wejście klienta na stronę odpytuje bazę i zeruje licznik. Ale w martwym sezonie albo
zaraz po uruchomieniu, gdy jeszcze nikt nie zna adresu, projekt może zasnąć i trzeba go
obudzić ręcznie w panelu (dane nie giną, ale przez chwilę strona nie działa).

Darmowe lekarstwo: niech GitHub sam puka do bazy raz dziennie. W repozytorium utwórz plik
`.github/workflows/budzik.yml` o treści z załączonego `budzik.yml`, wklej URL i klucz jako
sekrety repozytorium (`Settings` → `Secrets and variables` → `Actions`). To wszystko.

Pozostałe limity darmowego planu — 500 MB bazy, 5 GB transferu miesięcznie — przy grafiku
rezerwacji są nieosiągalne. Rezerwacja waży kilkaset bajtów. Zapełnisz to za jakieś dwieście lat.

---

## 7. Dane osobowe — dwa zdania, ale ważne

Zbierasz imię i telefon obcych ludzi, więc jesteś administratorem ich danych. W praktyce
potrzebujesz:

- krótkiej informacji, kto przetwarza dane, po co i jak długo je trzyma (link w stopce strony
  wystarczy — mogę ją napisać),
- nawyku kasowania starych rezerwacji, np. raz na kwartał, bo numer telefonu sprzed dwóch lat
  jest już tylko ryzykiem, nie zasobem.

Apka celowo nie zbiera niczego o zdrowiu. Pole „uwagi" jest dobrowolne i warto, żeby tak
zostało — dane o stanie zdrowia to zupełnie inna kategoria prawna, z wyższymi wymaganiami.
Rozmowę o przeciwwskazaniach lepiej przeprowadzić na miejscu albo przez telefon.
