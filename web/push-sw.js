// MomOS service worker: shows reminders with the right urgency, handles the
// Done / Snooze / Stop buttons, and tells an open app to sound the alarm.
const FN = 'https://kpvyarzywvoasgsvgcqh.supabase.co/functions/v1/notify-action';

const SHELL = 'momos-shell-v1';
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil((async () => {
  const keys = await caches.keys();
  await Promise.all(keys.filter((k) => k.startsWith('momos-shell-') && k !== SHELL).map((k) => caches.delete(k)));
  await self.clients.claim();
})()));

// Offline: the app's own files are cached so MomOS opens without internet.
// Pages and the loader are network-first; other files are served from cache and refreshed in the background.
self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;
  const p = url.pathname;
  const networkFirst = req.mode === 'navigate' || p.endsWith('/') || p.endsWith('.html') || p.endsWith('flutter_bootstrap.js') || p.endsWith('manifest.json');
  if (networkFirst) {
    event.respondWith(fetch(req).then((r) => {
      if (r.ok) { const c = r.clone(); caches.open(SHELL).then((cache) => cache.put(req, c)); }
      return r;
    }).catch(() => caches.match(req).then((hit) => hit || caches.match(self.registration.scope))));
    return;
  }
  event.respondWith(caches.open(SHELL).then(async (cache) => {
    const hit = await cache.match(req);
    const fresh = fetch(req).then((r) => { if (r.ok) cache.put(req, r.clone()); return r; }).catch(() => hit);
    return hit || fresh;
  }));
});

function optionsFor(d) {
  const base = {
    body: d.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-maskable-192.png',
    tag: d.tag || undefined,
    renotify: !!d.tag,
    timestamp: Date.now(),
    data: d,
  };
  const reminder = d.kind === 'reminder' && d.rid;
  if (d.level === 'alarm') {
    Object.assign(base, {
      requireInteraction: true,
      vibrate: [700, 250, 700, 250, 700, 250, 700, 250, 700, 250, 700],
      actions: reminder ? [{ action: 'stop', title: '🛑 Stop' }, { action: 'snooze10', title: '⏰ Snooze 10 min' }] : [],
    });
  } else if (d.level === 'important') {
    Object.assign(base, {
      requireInteraction: true,
      vibrate: [300, 150, 300, 150, 300],
      actions: reminder ? [{ action: 'done', title: '✅ Done' }, { action: 'snooze10', title: '⏰ 10 min' }] : [],
    });
  } else {
    Object.assign(base, {
      vibrate: [150],
      actions: reminder ? [{ action: 'done', title: '✅ Done' }, { action: 'snooze60', title: '⏰ In 1 hour' }] : [],
    });
  }
  return base;
}

self.addEventListener('push', (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { body: event.data && event.data.text() }; }
  event.waitUntil((async () => {
    await self.registration.showNotification(d.title || 'MomOS', optionsFor(d));
    // If the app is open, let it play the sound / show the alarm screen
    const wins = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    wins.forEach((c) => c.postMessage({ type: 'momos-push', payload: d }));
  })());
});

self.addEventListener('notificationclick', (event) => {
  const d = event.notification.data || {};
  event.notification.close();
  if (event.action && d.rid && d.tok) {
    event.waitUntil(fetch(FN, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ rid: d.rid, tok: d.tok, action: event.action }),
    }).catch(() => {}));
    return;
  }
  const url = (d.url || self.registration.scope) + (d.level === 'alarm' && d.rid ? '#alarm=' + d.rid : '');
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const c of all) {
      if (c.url.startsWith(self.registration.scope) && 'focus' in c) {
        c.postMessage({ type: 'momos-open', payload: d });
        return c.focus();
      }
    }
    return self.clients.openWindow(url);
  })());
});
