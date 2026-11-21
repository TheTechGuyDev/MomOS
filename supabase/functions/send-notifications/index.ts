// MomOS push sender. Called every minute by pg_cron (x-cron-secret header),
// or by a signed-in user with {"test": true} to receive a test notification.
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

const APP_URL = "https://thetechguydev.github.io/MomOS/";
const fmt = (iso: string) =>
  new Intl.DateTimeFormat("en-NG", { hour: "numeric", minute: "2-digit", timeZone: "Africa/Lagos" }).format(new Date(iso));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  webpush.setVapidDetails(
    Deno.env.get("VAPID_SUBJECT") ?? "mailto:momos@example.com",
    Deno.env.get("VAPID_PUBLIC_KEY")!,
    Deno.env.get("VAPID_PRIVATE_KEY")!,
  );
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  async function sendTo(userIds: string[], payload: Record<string, string>) {
    if (!userIds.length) return 0;
    const { data: subs } = await admin.from("push_subscriptions").select("*").in("user_id", userIds);
    let sent = 0;
    for (const s of subs ?? []) {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify(payload), { TTL: 3600 });
        sent++;
      } catch (e) {
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) await admin.from("push_subscriptions").delete().eq("id", s.id);
        else console.error("push failed", code);
      }
    }
    return sent;
  }

  async function familyOf(familyId: string) {
    const { data } = await admin.from("profiles").select("id").eq("family_id", familyId);
    return (data ?? []).map((p) => p.id as string);
  }

  // Test notification for the signed-in user
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: { user } } = await admin.auth.getUser(token);
    if (!user) return json({ error: "unauthorised" }, 401);
    const sent = await sendTo([user.id], { title: "MomOS 🌸", body: "Notifications are working! You'll get your reminders here.", url: APP_URL, tag: "test" });
    return json({ sent });
  }

  const now = new Date();
  const since = new Date(now.getTime() - 6 * 3600 * 1000).toISOString();
  let total = 0;

  // Due reminders
  const { data: due } = await admin.from("reminders").select("id,user_id,family_id,title,notes,due_at,shared")
    .eq("done", false).is("notified_at", null).lte("due_at", now.toISOString()).gt("due_at", since).limit(200);
  for (const r of due ?? []) {
    await admin.from("reminders").update({ notified_at: now.toISOString() }).eq("id", r.id);
    const to = r.shared ? await familyOf(r.family_id) : [r.user_id];
    total += await sendTo(to, {
      title: `🔔 ${r.title}`,
      body: r.notes ? r.notes : `Reminder for ${fmt(r.due_at)}`,
      url: APP_URL,
      tag: `reminder-${r.id}`,
    });
  }

  // Family events: timed events 1 hour before; all-day events at their start (8 AM)
  const soon = new Date(now.getTime() + 60 * 60 * 1000).toISOString();
  const { data: events } = await admin.from("family_events").select("id,family_id,title,starts_at,all_day,location,emoji")
    .is("notified_at", null).lte("starts_at", soon).gt("starts_at", since).limit(200);
  for (const e of events ?? []) {
    if (e.all_day && new Date(e.starts_at) > now) continue;
    await admin.from("family_events").update({ notified_at: now.toISOString() }).eq("id", e.id);
    total += await sendTo(await familyOf(e.family_id), {
      title: `${e.emoji} ${e.title}`,
      body: e.all_day ? "Today" : `Starts at ${fmt(e.starts_at)}${e.location ? " · " + e.location : ""}`,
      url: APP_URL,
      tag: `event-${e.id}`,
    });
  }

  return json({ reminders: due?.length ?? 0, events: events?.length ?? 0, sent: total });
});
