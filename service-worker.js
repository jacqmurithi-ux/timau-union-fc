"use strict";
const CACHE = "tufc-public-shell-v4";
const CORE = [
  "/",
  "/index.html",
  "/styles.css",
  "/script.js",
  "/manifest.webmanifest",
  "/assets/club-crest.jpg",
  "/assets/app-icon-192.svg",
  "/assets/app-icon-512.svg"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll(CORE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(
        keys.filter(key => key.startsWith("tufc-public-shell-") && key !== CACHE)
          .map(key => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;

  // Never cache private member/admin pages or API requests.
  if (url.pathname.startsWith("/app/") || url.pathname.startsWith("/rest/") || url.pathname.startsWith("/auth/")) return;

  // Cache only the explicit public shell assets; leave all other requests to the browser.
  if (!CORE.includes(url.pathname) && url.pathname !== "/") return;
  event.respondWith(
    fetch(request).then(response => {
      if (response.ok) {
        const copy = response.clone();
        caches.open(CACHE).then(cache => cache.put(request, copy));
      }
      return response;
    }).catch(() => caches.match(request).then(cached => cached || caches.match("/index.html")))
  );
});