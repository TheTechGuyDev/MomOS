// MomOS service worker: shows reminders with the right urgency, handles the
// Done / Snooze / Stop buttons, and tells an open app to sound the alarm.
const FN = 'https://kpvyarzywvoasgsvgcqh.supabase.co/functions/v1/notify-action';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

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
