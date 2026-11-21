// MomOS AI tutor. Uses ANTHROPIC_API_KEY (Claude) or GEMINI_API_KEY (Google) from function secrets.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const DAILY_LIMIT = 40;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: { user } } = await admin.auth.getUser(token);
    if (!user) return json({ error: "Please sign in again." }, 401);

    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { count } = await admin.from("tutor_usage").select("id", { count: "exact", head: true })
      .eq("user_id", user.id).gte("created_at", since);
    if ((count ?? 0) >= DAILY_LIMIT) {
      return json({ error: `You've asked ${DAILY_LIMIT} questions today. The tutor will be ready again tomorrow.` }, 429);
    }

    const body = await req.json();
    // Clean history: valid roles, no error bubbles, alternate roles, start with the user
    const raw = Array.isArray(body.messages) ? body.messages.slice(-12) : [];
    const msgs: { role: "user" | "assistant"; content: string }[] = [];
    for (const m of raw) {
      const role = m?.role === "assistant" ? "assistant" : m?.role === "user" ? "user" : null;
      const content = String(m?.content ?? "").slice(0, 2000).trim();
      if (!role || !content || content.startsWith("⚠️")) continue;
      if (msgs.length && msgs[msgs.length - 1].role === role) msgs[msgs.length - 1].content += "\n" + content;
      else msgs.push({ role, content });
    }
    while (msgs.length && msgs[0].role !== "user") msgs.shift();
    if (!msgs.length || msgs[msgs.length - 1].role !== "user") return json({ error: "Ask a question first." }, 400);

    const lesson = typeof body.lesson === "string" ? body.lesson.slice(0, 120) : "";
    const system =
      "You are a friendly, patient tutor inside MomOS, helping a busy Nigerian mum learn data analysis " +
      "(Excel, Google Sheets, SQL, Power BI, Python/pandas, and getting a junior analyst job). " +
      "Explain simply in short paragraphs, using everyday Nigerian examples (naira prices, Lagos shops, school fees) when helpful. " +
      "Keep answers under 200 words unless she asks for more. Use plain text and simple bullet points; no tables. " +
      "Encourage her warmly but stay accurate. If asked something unrelated to learning, answer briefly and kindly. " +
      "For SQL practice, the in-app SQL Lab has: customers(id, name, city, joined_on), products(id, name, category, price), " +
      "orders(id, customer_id, product_id, qty, order_date). " +
      (lesson ? `She is currently on the lesson: "${lesson}".` : "");

    const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!anthropicKey && !geminiKey) {
      return json({ error: "The AI tutor isn't switched on yet. An API key needs to be added in Supabase." }, 503);
    }

    let reply = "";
    if (anthropicKey) {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "x-api-key": anthropicKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
        body: JSON.stringify({
          model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-5-5",
          max_tokens: 700,
          system,
          messages: msgs,
        }),
      });
      const d = await r.json();
      if (!r.ok) { console.error(d); return json({ error: "The tutor is busy right now. Please try again." }, 502); }
      reply = (d.content ?? []).map((c: { text?: string }) => c.text ?? "").join("").trim();
    } else {
      const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents: msgs.map((m) => ({ role: m.role === "assistant" ? "model" : "user", parts: [{ text: m.content }] })),
          generationConfig: { maxOutputTokens: 800 },
        }),
      });
      const d = await r.json();
      if (!r.ok) { console.error(d); return json({ error: "The tutor is busy right now. Please try again." }, 502); }
      reply = (d.candidates?.[0]?.content?.parts ?? []).map((p: { text?: string }) => p.text ?? "").join("").trim();
    }

    await admin.from("tutor_usage").insert({ user_id: user.id });
    return json({ reply: reply || "Sorry, I couldn't think of an answer. Try asking another way." });
  } catch (e) {
    console.error(e);
    return json({ error: "Something went wrong. Please try again." }, 500);
  }
});
