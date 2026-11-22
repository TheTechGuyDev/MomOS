// MomOS push sender. Called every minute by pg_cron (x-cron-secret header),
// or by a signed-in user with {"test": true} to receive a test notification.
// Handles reminder levels, quiet hours, "next up" lines and the morning summary.
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

const APP_URL = "https://thetechguydev.github.io/MomOS/";
const TZ = "Africa/Lagos";
const time = (iso: string) => new Intl.DateTimeFormat("en-NG", { hour: "numeric", minute: "2-digit", timeZone: TZ }).format(new Date(iso));
const lagosHour = (d = new Date()) => Number(new Intl.DateTimeFormat("en-GB", { hour: "numeric", hour12: false, timeZone: TZ }).format(d)) % 24;
const lagosDate = (d = new Date()) => new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(d); // YYYY-MM-DD
const pick = <T,>(a: T[]) => a[Math.floor(Math.random() * a.length)];

function inQuiet(h: number, start: number, end: number) {
  if (start === end) return false;
  return start < end ? h >= start && h < end : h >= start || h < end;
}

async function sign(id: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(Deno.env.get("CRON_SECRET")!), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(id));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

const gentleLines = ["Time for this one 🌸", "A gentle nudge 💗", "Just a reminder, you've got this ✨", "Quick one for you 🙂"];
const importantLines = ["This one matters ⚠️", "Please don't miss this", "Important, take a moment for it"];
const alarmLines = ["It's time! Tap to stop the alarm", "Alarm: do this now", "Time's up, this needs you now"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  webpush.setVapidDetails(Deno.env.get("VAPID_SUBJECT") ?? APP_URL, Deno.env.get("VAPID_PUBLIC_KEY")!, Deno.env.get("VAPID_PRIVATE_KEY")!);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  async function sendTo(userIds: string[], payload: Record<string, unknown>) {
    if (!userIds.length) return 0;
    const { data: subs } = await admin.from("push_subscriptions").select("*").in("user_id", userIds);
    let sent = 0;
    for (const s of subs ?? []) {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify(payload), {
          TTL: 3600,
          urgency: payload.level === "gentle" ? "normal" : "high",
        });
        sent++;
      } catch (e) {
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) await admin.from("push_subscriptions").delete().eq("id", s.id);
        else console.error("push failed", code);
      }
    }
    return sent;
  }

  const profileCache = new Map<string, { id: string; display_name: string; family_id: string | null; quiet_start: number; quiet_end: number; morning_summary: boolean; summary_hour: number; last_summary_on: string | null }>();
  async function profile(id: string) {
    if (!profileCache.has(id)) {
      const { data } = await admin.from("profiles").select("id,display_name,family_id,quiet_start,quiet_end,morning_summary,summary_hour,last_summary_on").eq("id", id).maybeSingle();
      if (data) profileCache.set(id, data);
    }
    return profileCache.get(id);
  }
  async function familyOf(familyId: string) {
    const { data } = await admin.from("profiles").select("id").eq("family_id", familyId);
    return (data ?? []).map((p) => p.id as string);
  }
  async function nextUpFor(userId: string, familyId: string | null, after: string) {
    let q = admin.from("reminders").select("title,due_at").eq("done", false).gt("due_at", after)
      .lt("due_at", new Date(Date.now() + 24 * 3600e3).toISOString()).order("due_at").limit(1);
    q = familyId ? q.or(`user_id.eq.${userId},and(shared.eq.true,family_id.eq.${familyId})`) : q.eq("user_id", userId);
    const { data } = await q;
    return data?.[0];
  }

  // ----- Test notification for the signed-in user -----
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: { user } } = await admin.auth.getUser(token);
    if (!user) return json({ error: "unauthorised" }, 401);
    let level = "gentle";
    try { level = ((await req.json()).level as string) ?? "gentle"; } catch { /* default */ }
    const sent = await sendTo([user.id], {
      title: level === "alarm" ? "⏰ Test alarm" : level === "important" ? "⚠️ Test: important" : "MomOS 🌸",
      body: "Notifications are working! This is how your reminders will look.",
      url: APP_URL, tag: "test-" + level, level,
    });
    return json({ sent });
  }

  const now = new Date();
  const nowIso = now.toISOString();
  const hour = lagosHour(now);
  const since = new Date(now.getTime() - 12 * 3600e3).toISOString();
  let total = 0;

  // ----- Due reminders -----
  const { data: due } = await admin.from("reminders").select("id,user_id,family_id,title,notes,due_at,shared,level,repeat")
    .eq("done", false).is("notified_at", null).lte("due_at", nowIso).gt("due_at", since).order("due_at").limit(200);
  // Alarms that were not stopped ring again every minute, up to 5 times
  const { data: ringing } = await admin.from("reminders").select("id,user_id,family_id,title,notes,due_at,shared,level,repeat,alarm_rings")
    .eq("done", false).eq("level", "alarm").eq("alarm_acked", false).not("notified_at", "is", null)
    .lt("alarm_rings", 5).lte("due_at", nowIso).gt("due_at", since).limit(100);
  for (const r of ringing ?? []) {
    await admin.from("reminders").update({ alarm_rings: (r.alarm_rings ?? 0) + 1, notified_at: nowIso }).eq("id", r.id);
    const to = r.shared ? await familyOf(r.family_id) : [r.user_id];
    total += await sendTo(to, {
      title: `⏰ ${r.title}`,
      body: `Still waiting for you (${(r.alarm_rings ?? 0) + 2}/6). Tap Stop or Done.`,
      url: APP_URL, tag: `reminder-${r.id}`, level: "alarm", rid: r.id, tok: await sign(r.id), kind: "reminder",
    });
  }

  for (const r of due ?? []) {
    const owner = await profile(r.user_id);
    if (owner && r.level !== "alarm" && inQuiet(hour, owner.quiet_start, owner.quiet_end)) continue; // wait for morning
    await admin.from("reminders").update({ notified_at: nowIso }).eq("id", r.id);
    const next = await nextUpFor(r.user_id, r.family_id, r.due_at);
    const lead = r.level === "alarm" ? pick(alarmLines) : r.level === "important" ? pick(importantLines) : pick(gentleLines);
    const parts = [r.notes ? r.notes : lead];
    if (next) parts.push(`Next up: ${next.title} at ${time(next.due_at)}`);
    const icon = r.level === "alarm" ? "⏰" : r.level === "important" ? "⚠️" : "🔔";
    const to = r.shared ? await familyOf(r.family_id) : [r.user_id];
    total += await sendTo(to, {
      title: `${icon} ${r.title}`,
      body: parts.join("\n"),
      url: APP_URL,
      tag: `reminder-${r.id}`,
      level: r.level,
      rid: r.id,
      tok: await sign(r.id),
      kind: "reminder",
    });
  }

  // ----- Family events: timed ones 1 hour before; all-day at 8 AM -----
  const soon = new Date(now.getTime() + 3600e3).toISOString();
  const { data: events } = await admin.from("family_events").select("id,family_id,title,starts_at,all_day,location,emoji")
    .is("notified_at", null).lte("starts_at", soon).gt("starts_at", since).limit(200);
  for (const e of events ?? []) {
    if (e.all_day && new Date(e.starts_at) > now) continue;
    await admin.from("family_events").update({ notified_at: nowIso }).eq("id", e.id);
    total += await sendTo(await familyOf(e.family_id), {
      title: `${e.emoji} ${e.title}`,
      body: e.all_day ? "Today. Plan your day around it." : `Starts at ${time(e.starts_at)}${e.location ? " · " + e.location : ""}. Time to get ready.`,
      url: APP_URL, tag: `event-${e.id}`, level: "important", kind: "event",
    });
  }

  // ----- Morning summary -----
  const today = lagosDate(now);
  const { data: summaryUsers } = await admin.from("profiles").select("id,display_name,family_id,summary_hour,last_summary_on")
    .eq("morning_summary", true).lte("summary_hour", hour).or(`last_summary_on.is.null,last_summary_on.lt.${today}`);
  for (const p of summaryUsers ?? []) {
    if (hour > p.summary_hour + 3) continue; // too late in the day, skip until tomorrow
    await admin.from("profiles").update({ last_summary_on: today }).eq("id", p.id);
    const endOfDay = new Date(`${today}T23:59:59+01:00`).toISOString();
    let rq = admin.from("reminders").select("title,due_at").eq("done", false).gte("due_at", nowIso).lte("due_at", endOfDay).order("due_at").limit(10);
    rq = p.family_id ? rq.or(`user_id.eq.${p.id},and(shared.eq.true,family_id.eq.${p.family_id})`) : rq.eq("user_id", p.id);
    const { data: todays } = await rq;
    const { data: evs } = p.family_id
      ? await admin.from("family_events").select("title,starts_at").eq("family_id", p.family_id).gte("starts_at", `${today}T00:00:00+01:00`).lte("starts_at", endOfDay)
      : { data: [] };
    const nR = todays?.length ?? 0, nE = evs?.length ?? 0;
    const first = todays?.[0];
    const lines = [
      nR || nE ? `Today: ${nR} reminder${nR === 1 ? "" : "s"}${nE ? `, ${nE} family event${nE === 1 ? "" : "s"}` : ""}.` : "A clear day ahead. Maybe a short lesson or a walk?",
      first ? `First up: ${first.title} at ${time(first.due_at)}` : "",
      "Tap to see your plan and today's quests 🎯",
    ].filter(Boolean);
    total += await sendTo([p.id], {
      title: `Good morning, ${(p.display_name ?? "").split(" ")[0] || "Mama"} ☀️`,
      body: lines.join("\n"),
      url: APP_URL, tag: `summary-${today}`, level: "gentle", kind: "summary",
    });
  }

  return json({ reminders: due?.length ?? 0, events: events?.length ?? 0, sent: total });
});
