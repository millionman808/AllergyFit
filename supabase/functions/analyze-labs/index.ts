// AllergyFit — blood allergy test (IgE panel) photo analysis.
// Claude vision extracts test rows into structured data; the app lets the
// user review and confirm before anything is saved. NOT medical advice.
import Anthropic from "npm:@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SLUGS = [
  "peanut", "tree_nut", "dairy", "egg", "wheat", "gluten", "soy", "fish",
  "shellfish", "sesame", "corn", "nightshade", "histamine", "fodmap",
  "sulfite", "mustard", "celery", "lupin", "mollusc", "alpha_gal",
];

const SCHEMA = {
  type: "object",
  properties: {
    is_allergy_test: { type: "boolean" },
    tests: {
      type: "array",
      items: {
        type: "object",
        properties: {
          allergen: { type: "string" },
          value: { type: "string" },
          unit: { type: "string" },
          level: { type: "string" },
          positive: { type: "boolean" },
          matched_slug: { type: "string" },
        },
        required: ["allergen", "value", "unit", "level", "positive", "matched_slug"],
        additionalProperties: false,
      },
    },
    summary: { type: "string" },
  },
  required: ["is_allergy_test", "tests", "summary"],
  additionalProperties: false,
} as const;

const SYSTEM = `You read photos of blood allergy test results (IgE panels, RAST/ImmunoCAP class results, skin test reports).

Extract every allergen test row you can see. For each: the allergen name as printed, the measured value and unit (e.g. "3.2" "kU/L"), the class/level as printed (e.g. "Class 3", "High"), and whether the result indicates sensitization (positive = class 1+ / above reference range / flagged high).

Map each allergen to the closest slug from this fixed list, or "" if none fits: ${SLUGS.join(", ")}. (e.g. "Milk" -> dairy, "Almond" -> tree_nut, "Shrimp" -> shellfish, "Cod" -> fish.)

Only report what is legibly printed — never invent rows or values. If the image is not an allergy test result, set is_allergy_test=false and explain in summary. Keep summary to 1-2 sentences and include a reminder that results should be confirmed with an allergist.`;

// ---------- AI rate limiting + kill switch ----------
// Usage counts and the switch live server-side and are written ONLY by this
// (service-role) code, so the app can never raise its own limits.
const RL_URL = Deno.env.get("SUPABASE_URL") ?? "";
const RL_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const RL_DEFAULT_LIMIT = Number(Deno.env.get("DAILY_AI_LIMIT") ?? "50");

function rlUserId(auth: string | null): string | null {
  if (!auth) return null;
  const parts = auth.replace(/^Bearer\s+/i, "").split(".");
  if (parts.length < 2) return null;
  try {
    return JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"))).sub ?? null;
  } catch { return null; }
}

type RLResult = { ok: true } | { ok: false; status: number; message: string };

async function enforceAiLimit(auth: string | null): Promise<RLResult> {
  if (!RL_URL || !RL_KEY) return { ok: true };            // not configured → fail open
  const userId = rlUserId(auth);
  if (!userId) return { ok: true };   // demo / no account: allowed pre-launch (Anthropic budget cap backstops). At ship, remove demo + enable verify_jwt.
  const h = { apikey: RL_KEY, Authorization: `Bearer ${RL_KEY}`, "Content-Type": "application/json" };

  let limit = RL_DEFAULT_LIMIT;
  try {
    const cfg = await fetch(`${RL_URL}/rest/v1/service_config?id=eq.1&select=ai_enabled,daily_ai_limit`, { headers: h });
    if (cfg.ok) {
      const row = (await cfg.json())[0];
      if (row?.ai_enabled === false)
        return { ok: false, status: 503, message: "AI features are temporarily paused. Please try again shortly." };
      if (typeof row?.daily_ai_limit === "number") limit = row.daily_ai_limit;
    }
  } catch { /* fail open on config errors */ }

  try {
    const day = new Date().toISOString().slice(0, 10);
    const res = await fetch(`${RL_URL}/rest/v1/rpc/bump_ai_usage`, {
      method: "POST", headers: h, body: JSON.stringify({ p_user: userId, p_day: day }),
    });
    if (res.ok) {
      const count = await res.json();
      if (typeof count === "number" && count > limit)
        return { ok: false, status: 429, message: `You've reached today's AI limit (${limit} requests). It resets tomorrow.` };
    }
  } catch { /* fail open on counter errors */ }

  return { ok: true };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const gate = await enforceAiLimit(req.headers.get("Authorization"));
    if (!gate.ok) return json({ error: gate.message }, gate.status);

    const { image_base64, media_type } = await req.json();
    if (!image_base64) return json({ error: "image_base64 required" }, 400);

    const response = await anthropic.messages.create({
      model: "claude-opus-4-8",
      max_tokens: 4096,
      system: SYSTEM,
      messages: [{
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: media_type ?? "image/jpeg", data: image_base64 },
          },
          { type: "text", text: "Extract the allergy test results from this image." },
        ],
      }],
      output_config: { format: { type: "json_schema", schema: SCHEMA } },
    });

    const text = response.content.find((b) => b.type === "text");
    if (!text || text.type !== "text") throw new Error("no response text");
    return json(JSON.parse(text.text));
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
