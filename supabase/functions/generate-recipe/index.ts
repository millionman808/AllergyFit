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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { request = "", allergens = [], dietary = [], goal = "" } = await req.json();

    const system = `You are a chef and nutrition coach for people with food allergies.

Create ONE complete, appealing recipe. It must be 100% free of the user's allergens — not just the named allergen but every common hidden source of it (e.g. dairy hides in butter, whey, casein, ghee; wheat/gluten in soy sauce, breadcrumbs; egg in mayo). If unsure whether an ingredient is safe, choose a different ingredient.

Respect the user's dietary preferences and lean toward their fitness goal (e.g. higher protein for "build"). If the user named ingredients they have or a request, build around it. If they gave nothing, pick something crowd-pleasing and practical.

Write clear amounts and numbered steps a beginner can follow. In safe_note, state in one friendly sentence which of the user's triggers this recipe avoids and how. Nutrition is your best per-serving ESTIMATE — reasonable whole numbers.

Never criticize the user. Keep the tone warm and encouraging.`;

    const userMsg = [
      allergens.length ? `My allergens (must avoid): ${allergens.join(", ")}.` : "No known allergens.",
      dietary.length ? `Dietary preferences: ${dietary.join(", ")}.` : "",
      goal ? `Fitness goal: ${goal}.` : "",
      request ? `Request: ${request}` : "Surprise me with something safe and satisfying.",
    ].filter(Boolean).join("\n");

    const resp = await anthropic.messages.create({
      model: "claude-opus-4-8",
      max_tokens: 4096,
      system,
      messages: [{ role: "user", content: userMsg }],
      output_config: { format: { type: "json_schema", schema: SCHEMA } },
    });
    const text = resp.content.find((b) => b.type === "text");
    if (!text || text.type !== "text") throw new Error("no response text");
    return json({ recipe: JSON.parse(text.text) });
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
