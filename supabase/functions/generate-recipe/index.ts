// AllergyFit — AI recipe generator.
// Claude writes a complete recipe that avoids the user's allergens and respects
// dietary preferences. Nutrition is a labeled per-serving estimate (not logged).
import Anthropic from "npm:@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    description: { type: "string" },
    safe_note: { type: "string" },
    servings: { type: "integer" },
    total_time_minutes: { type: "integer" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        properties: { amount: { type: "string" }, name: { type: "string" } },
        required: ["amount", "name"],
        additionalProperties: false,
      },
    },
    steps: { type: "array", items: { type: "string" } },
    nutrition_per_serving: {
      type: "object",
      properties: {
        calories: { type: "integer" }, protein: { type: "integer" },
        carbs: { type: "integer" }, fat: { type: "integer" },
      },
      required: ["calories", "protein", "carbs", "fat"],
      additionalProperties: false,
    },
  },
  required: ["title", "description", "safe_note", "servings", "total_time_minutes", "ingredients", "steps", "nutrition_per_serving"],
  additionalProperties: false,
} as const;

// Allergen keyword safety-net — mirrors the recipe search function so generated
// recipes get the same double-check that browsed recipes do (independent of which
// model wrote them).
const KEYWORDS: Record<string, { name: string; words: string[] }> = {
  peanut: { name: "Peanut", words: ["peanut"] },
  tree_nut: { name: "Tree Nuts", words: ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia", "pine nut", "brazil nut", "praline"] },
  dairy: { name: "Dairy", words: ["milk", "butter", "cheese", "cream", "yogurt", "whey", "casein", "ghee", "buttermilk", "parmesan", "mozzarella", "cheddar", "ricotta"] },
  egg: { name: "Egg", words: ["egg", "mayonnaise", "mayo", "meringue", "aioli"] },
  wheat: { name: "Wheat", words: ["wheat", "flour", "bread", "breadcrumb", "pasta", "noodle", "cracker", "tortilla", "couscous"] },
  gluten: { name: "Gluten", words: ["wheat", "flour", "bread", "breadcrumb", "pasta", "noodle", "barley", "rye", "soy sauce", "beer", "couscous", "seitan"] },
  soy: { name: "Soy", words: ["soy", "tofu", "edamame", "tempeh", "miso"] },
  fish: { name: "Fish", words: ["salmon", "tuna", "cod", "tilapia", "anchov", "halibut", "trout", "sardine", "fish"] },
  shellfish: { name: "Shellfish", words: ["shrimp", "prawn", "crab", "lobster", "crawfish", "scampi"] },
  sesame: { name: "Sesame", words: ["sesame", "tahini"] },
  corn: { name: "Corn", words: ["corn", "cornstarch", "cornmeal", "polenta", "grits"] },
  mustard: { name: "Mustard", words: ["mustard"] },
  celery: { name: "Celery", words: ["celery"] },
  sulfite: { name: "Sulfites", words: ["wine", "dried apricot"] },
};

function flagAllergens(ingredientNames: string[], allergens: string[]): string[] {
  const hay = ingredientNames.join(" ").toLowerCase();
  const hits: string[] = [];
  for (const slug of allergens) {
    const entry = KEYWORDS[slug];
    if (entry && entry.words.some((w) => hay.includes(w))) hits.push(entry.name);
  }
  return hits;
}

const SYSTEM = `You are a chef and nutrition coach for people with food allergies.

Create ONE complete, appealing recipe. It must be 100% free of the user's allergens — not just the named allergen but every common hidden source of it (e.g. dairy hides in butter, whey, casein, ghee; wheat/gluten in soy sauce, breadcrumbs; egg in mayo). If unsure whether an ingredient is safe, choose a different ingredient.

Respect the user's dietary preferences and lean toward their fitness goal (e.g. higher protein for "build"). If the user named ingredients they have or a request, build around it. If they gave nothing, pick something crowd-pleasing and practical.

Write clear amounts and numbered steps a beginner can follow. In safe_note, state in one friendly sentence which of the user's triggers this recipe avoids and how. Nutrition is your best per-serving ESTIMATE — reasonable whole numbers.

Never criticize the user. Keep the tone warm and encouraging.`;

async function generateRecipe(userMsg: string) {
  const resp = await anthropic.messages.create({
    model: "claude-haiku-4-5",
    max_tokens: 4096,
    system: SYSTEM,
    messages: [{ role: "user", content: userMsg }],
    output_config: { format: { type: "json_schema", schema: SCHEMA } },
  });
  const text = resp.content.find((b) => b.type === "text");
  if (!text || text.type !== "text") throw new Error("no response text");
  return JSON.parse(text.text) as { ingredients: { name: string }[] } & Record<string, unknown>;
}

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

    const { request = "", allergens = [], dietary = [], goal = "" } = await req.json();

    const userMsg = [
      allergens.length ? `My allergens (must avoid): ${allergens.join(", ")}.` : "No known allergens.",
      dietary.length ? `Dietary preferences: ${dietary.join(", ")}.` : "",
      goal ? `Fitness goal: ${goal}.` : "",
      request ? `Request: ${request}` : "Surprise me with something safe and satisfying.",
    ].filter(Boolean).join("\n");

    let recipe = await generateRecipe(userMsg);
    let flagged = flagAllergens((recipe.ingredients ?? []).map((i) => i.name), allergens);

    // Safety-net: if a trigger slipped in, give the model one corrective pass.
    if (flagged.length) {
      const retryMsg = `${userMsg}\n\nCRITICAL: your previous recipe included ingredients that contain ${flagged.join(", ")}, which the user MUST avoid. Write a DIFFERENT recipe that completely avoids these and every hidden source of them.`;
      recipe = await generateRecipe(retryMsg);
      flagged = flagAllergens((recipe.ingredients ?? []).map((i) => i.name), allergens);
    }

    // Attach the verdict so the client can warn if anything still looks off.
    recipe.flagged = flagged;
    return json({ recipe });
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
