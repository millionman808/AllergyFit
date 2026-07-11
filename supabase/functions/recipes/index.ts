// AllergyFit — recipe search (ported from python-allrecipes scraping approach)
// Searches allrecipes.com, reads ingredients per recipe, and filters/flags
// against the user's allergen profile with a keyword map. No AI needed.
const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// allergen slug -> ingredient keywords
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

interface RecipeResult {
  title: string;
  url: string;
  image: string;
  calories: number | null;
  ingredients: string[];
  flagged: string[];
  directions: string[];
  protein: number | null;
  carbs: number | null;
  fat: number | null;
  servings: number | null;
}

async function fetchPage(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: { "user-agent": UA, "accept-language": "en-US,en;q=0.9" },
  });
  if (!res.ok) throw new Error(`fetch ${url} -> ${res.status}`);
  return await res.text();
}

function parseSearchCards(html: string): { title: string; url: string; image: string }[] {
  const cards: { title: string; url: string; image: string }[] = [];
  const chunks = html.split("mntl-card-list-items").slice(1);
  for (const chunk of chunks) {
    const href = chunk.match(/href="(https:\/\/www\.allrecipes\.com\/[^"]+)"/)?.[1];
    if (!href || !/\/recipe[s]?[\/-]/.test(href)) continue;
    const title = chunk.match(/card__title-text[^>]*>([^<]+)</)?.[1]?.trim();
    const image = chunk.match(/(?:data-src|srcset|src)="(https:\/\/www\.allrecipes\.com\/thmb\/[^"\s]+)/)?.[1] ?? "";
    if (!title) continue;
    if (cards.some((c) => c.url === href)) continue;
    cards.push({ title, url: href, image });
    if (cards.length >= 12) break;
  }
  return cards;
}

function parseDetail(html: string): { ingredients: string[]; calories: number | null; image: string | null } {
  const ingredients: string[] = [];
  const itemRe = /mntl-structured-ingredients__list-item[\s\S]*?<p>([\s\S]*?)<\/p>/g;
  let m;
  while ((m = itemRe.exec(html)) !== null) {
    const text = m[1].replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
    if (text) ingredients.push(text);
    if (ingredients.length >= 40) break;
  }
  if (ingredients.length === 0) {
    const nameRe = /data-ingredient-name="true"[^>]*>([^<]+)</g;
    while ((m = nameRe.exec(html)) !== null) ingredients.push(m[1].trim());
  }
  const cal = html.match(/(\d+)\s*<\/td>\s*<td[^>]*>\s*Calories/i)?.[1]
    ?? html.match(/Calories[\s\S]{0,80}?(\d{2,4})/i)?.[1];
  const image = html.match(/property="og:image"\s+content="([^"]+)"/)?.[1] ?? null;
  return { ingredients, calories: cal ? parseInt(cal) : null, image };
}

function flagAllergens(ingredients: string[], allergens: string[]): string[] {
  const text = ingredients.join(" ").toLowerCase();
  const flagged: string[] = [];
  for (const slug of allergens) {
    const entry = KEYWORDS[slug];
    if (!entry) continue;
    if (entry.words.some((w) => text.includes(w))) flagged.push(entry.name);
  }
  return flagged;
}

// Spoonacular — primary source when SPOONACULAR_API_KEY is set.
// 360k+ recipes, native intolerance filtering, calories included.
const SPOON_KEY = Deno.env.get("SPOONACULAR_API_KEY");
const SPOON_INTOLERANCES: Record<string, string> = {
  peanut: "peanut", dairy: "dairy", egg: "egg", wheat: "wheat", gluten: "gluten",
  soy: "soy", fish: "seafood", shellfish: "shellfish", sesame: "sesame",
  tree_nut: "tree nut", sulfite: "sulfite",
};

async function searchSpoonacular(query: string, allergens: string[]): Promise<RecipeResult[]> {
  if (!SPOON_KEY) return [];
  const url = new URL("https://api.spoonacular.com/recipes/complexSearch");
  url.searchParams.set("apiKey", SPOON_KEY);
  url.searchParams.set("query", query);
  url.searchParams.set("number", "12");
  url.searchParams.set("addRecipeInformation", "true");
  url.searchParams.set("addRecipeNutrition", "true");
  url.searchParams.set("fillIngredients", "true");
  const intolerances = allergens.map((s) => SPOON_INTOLERANCES[s]).filter(Boolean).join(",");
  if (intolerances) url.searchParams.set("intolerances", intolerances);
  const res = await fetch(url);
  if (!res.ok) throw new Error("spoonacular -> " + res.status);
  const data = await res.json();
  return (data.results ?? []).map((r: Record<string, unknown>) => {
    const ext = (r.extendedIngredients ?? (r.nutrition as Record<string, unknown>)?.ingredients ?? []) as Record<string, unknown>[];
    const ingredients = ext.map((i) => (i.original ?? i.name) as string).filter(Boolean);
    const nutrients = ((r.nutrition as Record<string, unknown>)?.nutrients ?? []) as { name: string; amount: number }[];
    const macro = (name: string) => {
      const v = nutrients.find((n) => n.name === name)?.amount;
      return v != null ? Math.round(v) : null;
    };
    const steps = (((r.analyzedInstructions as Record<string, unknown>[])?.[0]?.steps ?? []) as { step: string }[])
      .map((s) => s.step?.trim()).filter(Boolean) as string[];
    return {
      title: r.title as string,
      url: (r.sourceUrl as string) || `https://spoonacular.com/recipes/x-${r.id}`,
      image: (r.image as string) ?? "",
      calories: macro("Calories"),
      ingredients,
      // second safety layer: keyword-check even though Spoonacular pre-filters
      flagged: flagAllergens(ingredients, allergens),
      directions: steps,
      protein: macro("Protein"),
      carbs: macro("Carbohydrates"),
      fat: macro("Fat"),
      servings: typeof r.servings === "number" ? r.servings : null,
    };
  });
}

// TheMealDB fallback — free API, reliable from datacenter IPs.
async function searchMealDb(query: string, allergens: string[]): Promise<RecipeResult[]> {
  const res = await fetch(
    `https://www.themealdb.com/api/json/v1/1/search.php?s=${encodeURIComponent(query)}`,
  );
  const data = await res.json();
  return (data.meals ?? []).slice(0, 12).map((m: Record<string, string>) => {
    const ingredients: string[] = [];
    for (let i = 1; i <= 20; i++) {
      const ing = m[`strIngredient${i}`]?.trim();
      if (!ing) continue;
      const measure = m[`strMeasure${i}`]?.trim() ?? "";
      ingredients.push([measure, ing].filter(Boolean).join(" "));
    }
    const directions = (m.strInstructions ?? "")
      .split(/\r?\n+/)
      .flatMap((p) => p.split(/(?<=\.)\s+(?=[A-Z0-9])/))
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    return {
      title: m.strMeal,
      url: m.strSource || `https://www.themealdb.com/meal/${m.idMeal}`,
      image: m.strMealThumb ?? "",
      calories: null,
      ingredients,
      flagged: flagAllergens(ingredients, allergens),
      directions,
      protein: null,
      carbs: null,
      fat: null,
      servings: null,
    };
  });
}

async function searchAllrecipes(query: string, allergens: string[]): Promise<RecipeResult[]> {
  const searchHtml = await fetchPage(
    `https://www.allrecipes.com/search?q=${encodeURIComponent(query)}`,
  );
  const cards = parseSearchCards(searchHtml);
  return await Promise.all(
    cards.slice(0, 10).map(async (card) => {
      try {
        const detail = parseDetail(await fetchPage(card.url));
        return {
          title: card.title,
          url: card.url,
          image: card.image || detail.image || "",
          calories: detail.calories,
          ingredients: detail.ingredients,
          flagged: flagAllergens(detail.ingredients, allergens),
          directions: [],
          protein: null,
          carbs: null,
          fat: null,
          servings: null,
        };
      } catch {
        return { title: card.title, url: card.url, image: card.image, calories: null, ingredients: [], flagged: ["__unverified__"], directions: [], protein: null, carbs: null, fat: null, servings: null };
      }
    }),
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { query, allergens = [] } = await req.json();
    if (!query || typeof query !== "string") {
      return json({ error: "query required" }, 400);
    }

    let results: RecipeResult[] = [];
    try {
      results = await searchSpoonacular(query, allergens);
    } catch (_err) {
      // key missing/quota hit — fall through
    }
    if (results.length === 0) {
      try {
        results = await searchAllrecipes(query, allergens);
      } catch (_err) {
        // allrecipes blocks datacenter IPs — fall back to TheMealDB
      }
    }
    if (results.length === 0) {
      results = await searchMealDb(query, allergens);
    }

    // safe recipes first, flagged after
    results.sort((a, b) => a.flagged.length - b.flagged.length);
    return json({ results });
  } catch (err) {
    console.error(err);
    return json({ error: String(err), results: [] }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
