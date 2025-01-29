// static\js\service-worker.js, do not remove this line
const CACHE_NAME = 'household-task-tracker-cache-v1';
const urlsToCache = [
  '/',
  '/dashboard',
  '/stats',
  // Add routes, static assets, or compiled URLs you want cached
];

// Install event
self.addEventListener('install', event => {
  console.log('[Service Worker] Install Event processing');
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      console.log('[Service Worker] Caching pages during install');
      return cache.addAll(urlsToCache);
    })
  );
});

// Fetch event - serve from cache if offline
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        if (response) {
          return response; // return from cache
        }
        return fetch(event.request);
      })
  );
});

// Activate event
self.addEventListener('activate', event => {
  console.log('[Service Worker] Activate Event');
  event.waitUntil(
    caches.keys().then(cacheNames =>
      Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      )
    )
  );
});

// (Optional) For push events:
// self.addEventListener('push', event => {
//   const data = event.data ? event.data.json() : {};
//   event.waitUntil(
//     self.registration.showNotification(data.title, {
//       body: data.body,
//       icon: '/static/img/icon.png'
//     })
//   );
// });
