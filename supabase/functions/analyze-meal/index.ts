// AllergyFit — AI Meal Logger edge function
// Flow: Claude parses natural language → clarifying questions if info is missing
//       → USDA FoodData Central supplies ALL nutrition values (AI never invents numbers)
//       → Claude picks the best DB match + portion grams + allergens
//       → this function computes totals from DB values.
import Anthropic from "npm:@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });
const FDC_KEY = Deno.env.get("FDC_API_KEY") ?? "DEMO_KEY";

const ALLERGENS = [
  "Milk", "Egg", "Peanut", "Tree Nut", "Soy", "Wheat", "Fish", "Shellfish",
  "Sesame", "Mustard", "Celery", "Lupin", "Mollusks", "Sulfites",
];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ---------- Claude call 1: parse only (NO nutrition) ----------

const PARSE_SCHEMA = {
  type: "object",
  properties: {
    needs_clarification: { type: "boolean" },
    questions: { type: "array", items: { type: "string" } },
    foods: {
      type: "array",
      items: {
        type: "object",
        properties: {
          food: { type: "string" },
          quantity: { type: "number" },
          unit: { type: "string" },
          preparation: { type: "string" },
          brand: { type: "string" },
          restaurant: { type: "string" },
          confidence: { type: "number" },
        },
        required: ["food", "quantity", "unit", "preparation", "brand", "restaurant", "confidence"],
        additionalProperties: false,
      },
    },
  },
  required: ["needs_clarification", "questions", "foods"],
  additionalProperties: false,
} as const;

const PARSE_SYSTEM = `You are an expert nutrition parser. Extract every food mentioned in the user's meal description.

For every item return: food name, quantity, measurement unit, preparation method, brand name if specified, restaurant if specified, and your confidence (0-1) that you understood the item and its portion. Use "" for unknown string fields.

Accuracy over speed. If essential information is missing — portion size, count, size class (small/medium/large), preparation that changes calories (grilled vs fried), milk type, drink size — do NOT guess. Set needs_clarification=true and return short, specific clarifying questions like "How many slices of pizza?" or "Was the chicken grilled or fried?". Ask at most 3 questions.

If the user has already answered clarifying questions in the conversation, incorporate those answers and only ask about what is still genuinely missing.`;

// Recipe mode: estimate the whole ingredient list, never stop to ask questions.
const PARSE_SYSTEM_ESTIMATE = `You are an expert nutrition estimator for whole recipes. Extract every ingredient from the list.

For every item return: food name, quantity, measurement unit, preparation method, and confidence (0-1). Use "" for unknown string fields.

This is an automated best-effort estimate. Do NOT ask clarifying questions — ALWAYS set needs_clarification=false. When an amount is ambiguous, assume the most common cooking default (e.g. "1 chicken" ≈ one whole 1.4 kg chicken, "1 onion" ≈ 1 medium ~110 g, "oil" with no amount ≈ 1 tbsp, "salt to taste" ≈ a small pinch). Estimate reasonable standard amounts and proceed.`;

// Photo mode: read a meal from an image and estimate portions from visual cues.
const PARSE_SYSTEM_PHOTO = `You are an expert at identifying food from photographs.

Extract every distinct food and drink you can see in the image. For each, estimate the portion — a size class (small/medium/large), a count, or grams — from visual cues like plate size, utensils, and typical servings. Note preparation you can see (grilled, fried, breaded). Watch for likely hidden ingredients that matter for allergies (butter, cheese, dressing, breading, sauces) and include them when clearly present.

Do NOT ask clarifying questions — ALWAYS set needs_clarification=false. Give your best visual estimate and proceed. Return the same foods array format.`;

// ---------- Claude call 2: match + portions + allergens (nutrition comes from DB) ----------

const COMPOSE_SCHEMA = {
  type: "object",
  properties: {
    meal_name: { type: "string" },
    confidence: { type: "number" },
    suggestions: { type: "array", items: { type: "string" } },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          index: { type: "integer" },
          fdc_id: { type: "integer" },
          grams: { type: "number" },
          portion_estimated: { type: "boolean" },
          allergens: { type: "array", items: { type: "string", enum: ALLERGENS } },
          swappable: { type: "boolean" },
          substitutes: { type: "array", items: { type: "string" } },
        },
        required: ["index", "fdc_id", "grams", "portion_estimated", "allergens", "swappable", "substitutes"],
        additionalProperties: false,
      },
    },
  },
  required: ["meal_name", "confidence", "suggestions", "items"],
  additionalProperties: false,
} as const;

const COMPOSE_SYSTEM = `You are a nutrition-database matching expert. For each parsed food you receive a list of candidate entries from USDA FoodData Central with per-100g nutrient values.

For each food (by its index):
- pick the fdc_id of the candidate that best matches the food, brand, restaurant, and preparation. Prefer restaurant foods, then branded foods, then generic (Foundation/SR Legacy) foods. If NO candidate is a reasonable match, use fdc_id 0.
- convert the stated quantity+unit into total grams eaten (e.g. "2 large eggs" ≈ 100g, "1 tsp butter" ≈ 4.7g, "1 cup cooked rice" ≈ 158g). Set portion_estimated=true when the user did not give an exact amount and you estimated.
- list allergens present or very likely present in the food, from the fixed list only. Include cross-contamination-level risks only when typical for the food.

Also for each food: set swappable=false when the item has no meaningful substitute (salt, water, plain spices and seasonings, baking soda). When swappable=true, list 2-3 realistic substitutes that play the same role in the meal (e.g. butter -> "olive oil", "avocado"; white rice -> "quinoa", "cauliflower rice"; whey protein -> "rice protein", "pea protein"). Substitutes must avoid the user's allergens if an allergen list is provided in the input. substitutes must be an empty array when swappable=false.

Also return: a short natural meal_name (e.g. "Scrambled eggs with toast & butter"); an overall confidence 0-1 (lower it when serving sizes were estimated, brands unknown, or matches weak); and 1-3 positive, non-judgmental healthier-swap suggestions (e.g. "Swap butter for avocado for healthier fats"). Never criticize food choices.`;

interface ParsedFood {
  food: string; quantity: number; unit: string; preparation: string;
  brand: string; restaurant: string; confidence: number;
}

interface FdcCandidate {
  fdcId: number; description: string; dataType: string; brand?: string;
  per100g: Record<string, number>;
}

const NUTRIENT_IDS: Record<number, string> = {
  1008: "calories", 1003: "protein", 1004: "fat", 1005: "carbs",
  1079: "fiber", 2000: "sugar", 1093: "sodium",
};

async function searchFdc(food: ParsedFood): Promise<FdcCandidate[]> {
  const query = [food.brand, food.restaurant, food.food, food.preparation]
    .filter(Boolean).join(" ");
  const url = new URL("https://api.nal.usda.gov/fdc/v1/foods/search");
  url.searchParams.set("api_key", FDC_KEY);
  url.searchParams.set("query", query);
  url.searchParams.set("pageSize", "6");
  url.searchParams.set("dataType", "Foundation,SR Legacy,Branded");
  const res = await fetch(url);
  if (!res.ok) return [];
  const data = await res.json();
  return (data.foods ?? []).map((f: Record<string, unknown>) => {
    const per100g: Record<string, number> = {};
    for (const n of (f.foodNutrients as Record<string, unknown>[] ?? [])) {
      const key = NUTRIENT_IDS[n.nutrientId as number];
      if (key && typeof n.value === "number") per100g[key] = n.value;
    }
    return {
      fdcId: f.fdcId as number,
      description: f.description as string,
      dataType: f.dataType as string,
      brand: (f.brandName ?? f.brandOwner) as string | undefined,
      per100g,
    };
  }).filter((c: FdcCandidate) => Object.keys(c.per100g).length > 0);
}

function extractJson(msg: Anthropic.Message): unknown {
  const text = msg.content.find((b) => b.type === "text");
  if (!text || text.type !== "text") throw new Error("no text block in model response");
  return JSON.parse(text.text);
}

const round1 = (n: number) => Math.round(n * 10) / 10;

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
  if (!userId) return { ok: false, status: 401, message: "Please sign in to use AI features." };
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

    const { messages = [], allergens = [], estimate_only = false,
            image_base64, media_type } = await req.json();
    const isPhoto = typeof image_base64 === "string" && image_base64.length > 0;
    if (!isPhoto && (!Array.isArray(messages) || messages.length === 0)) {
      return json({ error: "messages array or image required" }, 400);
    }

    // Photo: build a vision message; otherwise use the text conversation.
    const parseMessages = isPhoto
      ? [{
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: media_type ?? "image/jpeg", data: image_base64 } },
            { type: "text", text: "Identify every food and drink in this photo of a meal and estimate each portion." },
          ],
        }]
      : messages;
    const parseSystem = isPhoto ? PARSE_SYSTEM_PHOTO : (estimate_only ? PARSE_SYSTEM_ESTIMATE : PARSE_SYSTEM);

    // --- Stage 1: parse the meal (no nutrition) ---
    const parseResp = await anthropic.messages.create({
      model: "claude-haiku-4-5",
      max_tokens: 4096,
      system: parseSystem,
      messages: parseMessages,
      output_config: { format: { type: "json_schema", schema: PARSE_SCHEMA } },
    });
    const parsed = extractJson(parseResp) as {
      needs_clarification: boolean; questions: string[]; foods: ParsedFood[];
    };

    // Recipe-estimate and photo modes never bounce back with questions.
    if (!estimate_only && !isPhoto && parsed.needs_clarification && parsed.questions.length > 0) {
      return json({ needs_clarification: true, questions: parsed.questions });
    }
    if (parsed.foods.length === 0) {
      return json({
        needs_clarification: true,
        questions: ["I'm not confident I understood your meal. Could you describe it with a little more detail?"],
      });
    }

    // --- Stage 2: verified nutrition lookup (USDA FoodData Central) ---
    const candidateLists = await Promise.all(parsed.foods.map(searchFdc));

    // --- Stage 3: match candidates, portions, allergens, substitutes ---
    const composeInput = {
      user_allergens: allergens,
      foods: parsed.foods.map((f, i) => ({
        index: i, food: f,
        candidates: candidateLists[i].map((c) => ({
          fdc_id: c.fdcId, description: c.description, data_type: c.dataType,
          brand: c.brand, per_100g: c.per100g,
        })),
      })),
    };
    const composeResp = await anthropic.messages.create({
      model: "claude-haiku-4-5",
      max_tokens: 4096,
      system: COMPOSE_SYSTEM,
      messages: [{ role: "user", content: JSON.stringify(composeInput) }],
      output_config: { format: { type: "json_schema", schema: COMPOSE_SCHEMA } },
    });
    const composed = extractJson(composeResp) as {
      meal_name: string; confidence: number; suggestions: string[];
      items: {
        index: number; fdc_id: number; grams: number; portion_estimated: boolean;
        allergens: string[]; swappable: boolean; substitutes: string[];
      }[];
    };

    // --- Stage 4: compute nutrition from DB values only ---
    const items = composed.items.map((item) => {
      const food = parsed.foods[item.index];
      const match = candidateLists[item.index]?.find((c) => c.fdcId === item.fdc_id);
      const scale = match ? item.grams / 100 : 0;
      const nut = (key: string) => round1((match?.per100g[key] ?? 0) * scale);
      return {
        food: food?.food ?? "Unknown",
        quantity: food?.quantity ?? 0,
        unit: food?.unit ?? "",
        preparation: food?.preparation ?? "",
        grams: round1(item.grams),
        fdc_id: match?.fdcId ?? null,
        fdc_description: match?.description ?? null,
        needs_review: !match,
        portion_estimated: item.portion_estimated,
        allergens: item.allergens,
        swappable: item.swappable,
        substitutes: item.swappable ? item.substitutes : [],
        calories: nut("calories"),
        protein: nut("protein"),
        carbs: nut("carbs"),
        fat: nut("fat"),
        fiber: nut("fiber"),
        sugar: nut("sugar"),
        sodium: nut("sodium"),
      };
    });

    const total = (key: string) =>
      round1(items.reduce((s, it) => s + (it[key as keyof typeof it] as number), 0));
    const contains = ALLERGENS.filter((a) => items.some((it) => it.allergens.includes(a)));

    return json({
      needs_clarification: false,
      meal: {
        name: composed.meal_name,
        confidence: Math.max(0, Math.min(1, composed.confidence)),
        items,
        totals: {
          calories: total("calories"), protein: total("protein"), carbs: total("carbs"),
          fat: total("fat"), fiber: total("fiber"), sugar: total("sugar"), sodium: total("sodium"),
        },
        allergens: { contains, safe: ALLERGENS.filter((a) => !contains.includes(a)) },
        suggestions: composed.suggestions,
      },
    });
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
