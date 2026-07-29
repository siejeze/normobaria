/* =====================================================================
   Service worker grafiku normobarii.

   Reguła nadrzędna: WYGLĄD z pamięci, DANE z sieci.
   Wolne terminy nigdy nie są cache'owane — inaczej klient zobaczyłby
   wczorajszy grafik i zapisał się na zajętą godzinę.
   ===================================================================== */

const WERSJA   = "normobaria-v4";
const SZKIELET = WERSJA + "-szkielet";
const KROJE    = WERSJA + "-kroje";

const DO_ZAPAMIETANIA = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./ikony/ikona-192.png",
  "./ikony/ikona-512.png",
  "./ikony/ikona-maskable-512.png",
  "./ikony/apple-touch-icon.png",
];

self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(SZKIELET)
      .then((c) => c.addAll(DO_ZAPAMIETANIA))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((klucze) => Promise.all(
        klucze.filter((k) => !k.startsWith(WERSJA)).map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;                 // zapisy idą prosto do bazy
  const url = new URL(req.url);

  // 1. Baza — zawsze sieć, nigdy pamięć podręczna.
  if (url.hostname.endsWith("supabase.co")) return;

  // 2. Kroje pisma z Google — pamięć, a w tle odświeżenie.
  if (url.hostname.includes("fonts.g")) {
    e.respondWith(
      caches.open(KROJE).then(async (c) => {
        const zapamietane = await c.match(req);
        const z_sieci = fetch(req).then((odp) => { c.put(req, odp.clone()); return odp; })
                                  .catch(() => zapamietane);
        return zapamietane || z_sieci;
      })
    );
    return;
  }

  // 3. Wszystko własne — pamięć od razu, aktualizacja w tle.
  if (url.origin === self.location.origin) {
    e.respondWith(
      caches.open(SZKIELET).then(async (c) => {
        const zapamietane = await c.match(req, { ignoreSearch: true });
        const z_sieci = fetch(req)
          .then((odp) => { if (odp.ok) c.put(req, odp.clone()); return odp; })
          .catch(() => zapamietane || c.match("./index.html"));
        return zapamietane || z_sieci;
      })
    );
  }
});
