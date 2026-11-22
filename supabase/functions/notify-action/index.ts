// Handles the buttons on a reminder notification (Done / Snooze) without opening the app.
// Each notification carries an HMAC token for its reminder id, so only real notifications can act.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

async function sign(id: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(Deno.env.get("CRON_SECRET")!), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(id));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { rid, tok, action } = await req.json();
    if (typeof rid !== "string" || typeof tok !== "string" || tok !== (await sign(rid))) return json({ error: "invalid" }, 403);
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    if (action === "done") {
      await admin.from("reminders").update({ done: true }).eq("id", rid);
    } else if (action === "stop") {
      await admin.from("reminders").update({ alarm_acked: true }).eq("id", rid);
    } else if (action === "snooze10" || action === "snooze60") {
      const mins = action === "snooze10" ? 10 : 60;
      await admin.from("reminders").update({ due_at: new Date(Date.now() + mins * 60e3).toISOString(), notified_at: null }).eq("id", rid);
    } else {
      return json({ error: "unknown action" }, 400);
    }
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ error: "failed" }, 500);
  }
});
