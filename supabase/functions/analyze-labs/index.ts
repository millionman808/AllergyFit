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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
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
