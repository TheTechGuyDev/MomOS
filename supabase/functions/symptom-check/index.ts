// MomOS symptom checker helper. The app decides urgency with fixed safety rules;
// this function only adds plain-language explanations and self-care tips (never doses),
// and is told never to lower the urgency it is given.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const DAILY_LIMIT = 20;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: { user } } = await admin.auth.getUser(token);
    if (!user) return json({ error: "Please sign in again." }, 401);

    const since = new Date(Date.now() - 24 * 3600e3).toISOString();
    const { count } = await admin.from("symptom_ai_usage").select("id", { count: "exact", head: true }).eq("user_id", user.id).gte("created_at", since);
    if ((count ?? 0) >= DAILY_LIMIT) return json({ error: "limit" }, 429);

    const b = await req.json();
    const clip = (v: unknown, n = 300) => String(v ?? "").slice(0, n);
    const symptoms = (Array.isArray(b.symptoms) ? b.symptoms : []).slice(0, 20).map((s: unknown) => clip(s, 60));
    const urgency = ["emergency", "doctor_today", "doctor_soon", "self_care"].includes(b.urgency) ? b.urgency : "doctor_soon";
    const person = clip(b.person, 120);
    const answers = clip(JSON.stringify(b.answers ?? {}), 800);
    const notes = clip(b.notes, 400);

    const system =
      "You support a mother in Lagos, Nigeria, using a family wellbeing app. You give general health information, not a diagnosis. " +
      "Rules: never give medicine names with doses or dosing schedules; for medicines say to follow the label or ask a pharmacist or doctor. " +
      "Never say something is definitely a condition; use 'could be' and 'common causes include'. " +
      "The app has already set the urgency level using safety rules. You MUST NOT lower it or contradict it. " +
      "Include Nigeria-relevant context where it fits (e.g. fever should be tested for malaria with an RDT at a clinic or pharmacy; avoid self-treating 'typhoid' without a proper test). " +
      "For a baby, remind to keep breastfeeding/feeding and watch wet diapers. Keep every item short (under 20 words), warm and practical. " +
      "Reply ONLY with JSON: {\"possible_causes\":[{\"name\":\"\",\"why\":\"\"}],\"self_care\":[\"\"],\"watch_for\":[\"\"],\"ask_doctor\":[\"\"]} " +
      "with 2-4 possible_causes, 3-5 self_care, 3-4 watch_for, 2-3 ask_doctor.";
    const prompt = `Person: ${person}\nSymptoms: ${symptoms.join(", ")}\nAnswers: ${answers}\nExtra notes: ${notes || "none"}\nUrgency already decided by safety rules: ${urgency}`;

    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) return json({ error: "ai_off" }, 503);
    const models = ["gemini-3.1-flash-lite", "gemini-flash-lite-latest", "gemini-3.5-flash-lite"];
    for (const model of models) {
      const ctl = new AbortController();
      const timer = setTimeout(() => ctl.abort(), 20000);
      try {
        const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`, {
          method: "POST", signal: ctl.signal, headers: { "content-type": "application/json" },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: system }] },
            contents: [{ role: "user", parts: [{ text: prompt }] }],
            generationConfig: { maxOutputTokens: 1200, responseMimeType: "application/json" },
          }),
        });
        const d = await r.json();
        if (!r.ok) { console.error(model, d.error?.message); continue; }
        const text = (d.candidates?.[0]?.content?.parts ?? []).map((p: { text?: string }) => p.text ?? "").join("");
        const parsed = JSON.parse(text.replace(/^```json|```$/g, "").trim());
        await admin.from("symptom_ai_usage").insert({ user_id: user.id });
        return json(parsed);
      } catch (e) {
        console.error(model, String(e));
      } finally {
        clearTimeout(timer);
      }
    }
    return json({ error: "busy" }, 502);
  } catch (e) {
    console.error(e);
    return json({ error: "failed" }, 500);
  }
});
