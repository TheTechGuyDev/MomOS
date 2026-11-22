// HerAssistant: the AI behind MomOS.
// Modes: chat (answers + proposed actions she confirms in the app), summary (day plan),
// cook (meal ideas from ingredients), outfit (pick an outfit from her wardrobe).
// Reads use the signed-in user's token, so Row Level Security applies: it only sees what she can see.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const TZ = "Africa/Lagos";
const DAILY_LIMIT = 80;

const fmt = (iso: string) =>
  new Intl.DateTimeFormat("en-NG", { weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit", timeZone: TZ }).format(new Date(iso));
const lagosDate = (d = new Date()) => new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(d);

async function gemini(system: string, contents: unknown[], asJson: boolean, maxTokens = 1400) {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("ai_off");
  for (const model of ["gemini-3.1-flash-lite", "gemini-flash-lite-latest", "gemini-3.5-flash-lite"]) {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 25000);
    try {
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`, {
        method: "POST", signal: ctl.signal, headers: { "content-type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents,
          generationConfig: { maxOutputTokens: maxTokens, ...(asJson ? { responseMimeType: "application/json" } : {}) },
        }),
      });
      const d = await r.json();
      if (!r.ok) { console.error(model, d.error?.message); continue; }
      const text = (d.candidates?.[0]?.content?.parts ?? []).map((p: { text?: string }) => p.text ?? "").join("").trim();
      if (text) return text;
    } catch (e) {
      console.error(model, String(e));
    } finally {
      clearTimeout(timer);
    }
  }
  throw new Error("busy");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const url = Deno.env.get("SUPABASE_URL")!;
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: { user } } = await admin.auth.getUser(auth.replace("Bearer ", ""));
    if (!user) return json({ error: "Please sign in again." }, 401);
    // Client that acts as her (RLS applies)
    const db = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: auth } } });

    const since = new Date(Date.now() - 24 * 3600e3).toISOString();
    const { count } = await admin.from("tutor_usage").select("id", { count: "exact", head: true }).eq("user_id", user.id).gte("created_at", since);
    if ((count ?? 0) >= DAILY_LIMIT) return json({ error: "You've reached today's assistant limit. It resets tomorrow." }, 429);

    const body = await req.json();
    const mode = String(body.mode ?? "chat");

    // ---------- small modes ----------
    if (mode === "cook") {
      const ing = (body.ingredients ?? []).slice(0, 30).map((s: unknown) => String(s).slice(0, 40));
      const avoid = [...(body.dislikes ?? []), ...(body.allergies ?? [])].slice(0, 20).map((s: unknown) => String(s).slice(0, 40));
      const sys = "You are a Nigerian home-cooking helper. Suggest 3 practical meals (Nigerian dishes first) using mostly the given ingredients. " +
        "Avoid these foods completely: " + (avoid.join(", ") || "none") + ". Reply ONLY JSON: " +
        "{\"ideas\":[{\"name\":\"\",\"time\":\"30 min\",\"missing\":[\"\"],\"steps\":[\"\"]}]} with 4-6 short steps each.";
      const t = await gemini(sys, [{ role: "user", parts: [{ text: "I have: " + ing.join(", ") }] }], true);
      await admin.from("tutor_usage").insert({ user_id: user.id });
      return json(JSON.parse(t));
    }
    if (mode === "outfit") {
      const items = (body.items ?? []).slice(0, 150);
      const sys = "You are a warm Nigerian fashion stylist. From the wardrobe list, choose 2-4 item ids that go well together for the occasion " +
        "(consider colours, Nigerian occasions like owambe, church, office). Only use ids from the list. Reply ONLY JSON: {\"name\":\"\",\"why\":\"one or two sentences\",\"item_ids\":[\"\"]}";
      const t = await gemini(sys, [{ role: "user", parts: [{ text: `Occasion: ${String(body.occasion).slice(0, 40)}\nWardrobe: ${JSON.stringify(items)}` }] }], true);
      await admin.from("tutor_usage").insert({ user_id: user.id });
      return json(JSON.parse(t));
    }

    // ---------- context for chat and summary ----------
    const today = lagosDate();
    const in7 = new Date(Date.now() + 7 * 86400e3).toISOString();
    const [prof, rem, ev, house, shop, pantry, bills, kids, kidTasks, goals, meals, chores] = await Promise.all([
      db.from("profiles").select("display_name").eq("id", user.id).maybeSingle(),
      db.from("reminders").select("title,due_at,level").eq("done", false).lte("due_at", in7).order("due_at").limit(20),
      db.from("family_events").select("title,starts_at,all_day,location").gte("starts_at", new Date().toISOString()).lte("starts_at", in7).order("starts_at").limit(15),
      db.from("household_tasks").select("title,next_due,frequency").lte("next_due", lagosDate(new Date(Date.now() + 86400e3))).limit(15),
      db.from("shopping_items").select("name,qty").eq("checked", false).eq("archived", false).limit(40),
      db.from("inventory_items").select("name,qty,unit,expires_on,place").gt("qty", 0).limit(60),
      db.from("bills").select("name,amount,next_due").lte("next_due", lagosDate(new Date(Date.now() + 7 * 86400e3))).limit(10),
      db.from("children").select("name,birth_date").limit(10),
      db.from("kid_tasks").select("title,category,due_date").eq("done", false).limit(15),
      db.from("goals").select("title,period").eq("done", false).eq("user_id", user.id).limit(10),
      db.from("meal_plans").select("week_start,plan").order("week_start", { ascending: false }).limit(1),
      db.from("chores").select("title,due_date").eq("done", false).limit(10),
    ]);
    const name = (prof.data?.display_name ?? "").split(" ")[0] || "Mama";
    const ctx = [
      `Now: ${fmt(new Date().toISOString())} (Lagos). Today is ${today}.`,
      `Her name: ${name}. Children: ${(kids.data ?? []).map((k) => `${k.name} (born ${k.birth_date})`).join(", ") || "none added"}.`,
      `Reminders (next 7 days): ${(rem.data ?? []).map((r) => `${r.title} @ ${fmt(r.due_at)}`).join("; ") || "none"}.`,
      `Family events (next 7 days): ${(ev.data ?? []).map((e) => `${e.title} @ ${fmt(e.starts_at)}`).join("; ") || "none"}.`,
      `Household jobs due by tomorrow: ${(house.data ?? []).map((h) => `${h.title} (${h.next_due})`).join("; ") || "none"}.`,
      `Chores: ${(chores.data ?? []).map((c) => c.title).join("; ") || "none"}.`,
      `School tasks: ${(kidTasks.data ?? []).map((k) => `${k.title} [${k.category}] ${k.due_date ?? ""}`).join("; ") || "none"}.`,
      `Bills due within 7 days: ${(bills.data ?? []).map((b) => `${b.name} ₦${b.amount ?? "?"} on ${b.next_due}`).join("; ") || "none"}.`,
      `Shopping list: ${(shop.data ?? []).map((s) => s.name + (s.qty ? ` (${s.qty})` : "")).join(", ") || "empty"}.`,
      `Pantry: ${(pantry.data ?? []).map((p) => `${p.name}${p.expires_on ? ` (use by ${p.expires_on})` : ""}`).join(", ") || "not tracked"}.`,
      `Goals: ${(goals.data ?? []).map((g) => g.title).join("; ") || "none"}.`,
      `Meal plan (latest week starting ${meals.data?.[0]?.week_start ?? "none"}): ${JSON.stringify(meals.data?.[0]?.plan ?? {})}`,
    ].join("\n");

    if (mode === "summary") {
      const sys = "You write a warm, encouraging 3-4 sentence plan for a busy Nigerian mum's day, based only on the data given. " +
        "Mention the most important things in time order, one practical tip, and end with something kind about taking a moment for herself. " +
        "Plain text, no lists, no markdown, under 90 words. If there is little planned, say so gently and suggest one nice thing to do.";
      const t = await gemini(sys, [{ role: "user", parts: [{ text: ctx }] }], false, 400);
      await admin.from("tutor_usage").insert({ user_id: user.id });
      return json({ reply: t.replace(/\*\*/g, "") });
    }

    // ---------- chat with actions ----------
    const raw = Array.isArray(body.messages) ? body.messages.slice(-14) : [];
    const contents: { role: string; parts: { text: string }[] }[] = [];
    for (const m of raw) {
      const role = m?.role === "assistant" ? "model" : "user";
      const text = String(m?.content ?? "").slice(0, 2000).trim();
      if (!text) continue;
      if (contents.length && contents[contents.length - 1].role === role) contents[contents.length - 1].parts[0].text += "\n" + text;
      else contents.push({ role, parts: [{ text }] });
    }
    while (contents.length && contents[0].role !== "user") contents.shift();
    if (!contents.length) return json({ error: "Say something first." }, 400);

    const sys = `You are "HerAssistant", the friendly personal assistant inside MomOS for ${name}, a busy mum in Lagos, Nigeria.
You help her plan her day, home, kitchen, children, shopping and money. Be warm, brief and practical (under 120 words). Use Nigerian context (naira, local foods, markets).
You can PROPOSE actions; the app shows them to her as cards and only saves them after she taps Add. Never say you have done, set, added or created anything. Say things like "Here's a reminder for you to add" or "Tap Add to save these".
Times are Lagos time. Convert phrases like "tomorrow", "this weekend", "next Monday" into exact ISO date-times with +01:00 offset.

Reply ONLY with JSON:
{"reply":"what you say to her","actions":[ ... ]}
Allowed actions (use only these shapes):
{"type":"reminder","title":"","due_at":"2026-11-23T09:00:00+01:00","level":"gentle|important|alarm","repeat":"none|daily|weekly|monthly","notes":""}
{"type":"shopping","items":[{"name":"","qty":"","category":"food|baby|household|health|school|other"}]}
{"type":"event","title":"","starts_at":"ISO","all_day":false,"location":""}
{"type":"household","title":"","frequency":"daily|weekly|monthly|once","next_due":"YYYY-MM-DD"}
{"type":"school","child":"child name","title":"","category":"homework|exam|school_event|supplies|medical|activity","due_date":"YYYY-MM-DD"}
{"type":"expense","amount":0,"category":"food|household|children|transport|bills|health|personal|clothing|giving|family|business|other","note":""}
{"type":"goal","title":"","period":"daily|weekly|once"}
{"type":"plan_meals","week":"this|next"}
{"type":"pantry","items":[{"name":"","qty":1,"unit":"","place":"kitchen|fridge|freezer"}]}
Only include actions she asked for or clearly needs; otherwise "actions":[].
For budgets like "I have ₦50,000 for groceries", give a short breakdown in the reply and propose a shopping action with the items.
For "I have visitors tomorrow", propose a few reminders/household jobs and a shopping list.

Her current data:
${ctx}`;
    const t = await gemini(sys, contents, true, 1600);
    let out: { reply?: string; actions?: unknown[] };
    try { out = JSON.parse(t); } catch { out = { reply: t, actions: [] }; }
    await admin.from("tutor_usage").insert({ user_id: user.id });
    return json({ reply: String(out.reply ?? "").replace(/\*\*/g, ""), actions: Array.isArray(out.actions) ? out.actions.slice(0, 12) : [] });
  } catch (e) {
    console.error(e);
    const msg = String((e as Error).message ?? e);
    if (msg === "ai_off") return json({ error: "The assistant isn't switched on yet." }, 503);
    return json({ error: "The assistant is busy right now. Please try again." }, 502);
  }
});
