// MomOS service worker: shows push notifications and opens the app when tapped.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (e) { data = { body: event.data && event.data.text() }; }
  const title = data.title || 'MomOS';
  event.waitUntil(self.registration.showNotification(title, {
    body: data.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: data.tag || undefined,
    renotify: !!data.tag,
    data: { url: data.url || self.registration.scope },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || self.registration.scope;
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of all) {
      if (c.url.startsWith(self.registration.scope) && 'focus' in c) return c.focus();
    }
    return self.clients.openWindow(url);
  })());
});
