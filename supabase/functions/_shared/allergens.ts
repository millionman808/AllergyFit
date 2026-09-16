// Allergen keyword safety-net shared by generate-recipe and recipes.
// Mirrors AllergyFit/Core/AllergenKeywords.swift — keep the two in sync.
//
// Fail-safe (over-flag rather than miss a hidden source), but a naive substring
// match flagged "coconut milk" as dairy and "eggplant" as egg, and a warning
// that cries wolf is one people learn to ignore. Each trigger therefore also
// lists the safe phrases that contain its keywords; those are stripped before
// matching, and keywords must start at a word boundary.

type Entry = { name: string; words: string[]; safe: string[] };

export const KEYWORDS: Record<string, Entry> = {
  peanut: { name: "Peanut", words: ["peanut"], safe: ["peanut-free"] },
  tree_nut: {
    name: "Tree Nuts",
    words: ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia", "pine nut", "brazil nut", "praline", "marzipan"],
    safe: ["nut-free"],
  },
  dairy: {
    name: "Dairy",
    words: ["milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey", "casein", "ghee", "buttermilk", "parmesan", "mozzarella", "cheddar", "ricotta", "feta", "brie", "kefir", "custard"],
    safe: ["coconut milk", "almond milk", "oat milk", "soy milk", "rice milk", "cashew milk", "hemp milk", "pea milk", "macadamia milk", "hazelnut milk", "plant milk", "plant-based milk", "non-dairy milk", "dairy-free",
      "coconut cream", "coconut yogurt", "coconut yoghurt", "almond yogurt", "soy yogurt", "oat yogurt", "cashew cream", "cream of tartar", "creamer",
      "peanut butter", "almond butter", "cashew butter", "sunflower butter", "sunflower seed butter", "seed butter", "nut butter", "cocoa butter", "apple butter", "shea butter", "vegan butter", "plant butter",
      "vegan cheese", "cashew cheese", "nutritional yeast", "cream-style corn"],
  },
  egg: {
    name: "Egg",
    words: ["egg", "mayonnaise", "mayo", "meringue", "aioli", "albumen"],
    safe: ["eggplant", "egg-free", "vegan mayo", "vegan mayonnaise", "egg replacer", "flax egg", "chia egg"],
  },
  wheat: {
    name: "Wheat",
    words: ["wheat", "flour", "bread", "breadcrumb", "pasta", "noodle", "cracker", "tortilla", "couscous", "bulgur", "semolina", "farro", "spelt", "seitan"],
    safe: ["buckwheat", "almond flour", "coconut flour", "rice flour", "oat flour", "chickpea flour", "cassava flour", "tapioca flour", "corn flour", "cornflour", "quinoa flour", "sorghum flour", "teff flour", "arrowroot flour", "potato flour", "gluten-free flour", "wheat-free", "gluten-free",
      "rice noodle", "zucchini noodle", "sweet potato noodle", "glass noodle", "shirataki noodle", "kelp noodle", "chickpea pasta", "rice pasta", "lentil pasta", "corn pasta", "gluten-free pasta",
      "corn tortilla", "rice cracker", "gluten-free bread", "cornbread"],
  },
  gluten: {
    name: "Gluten",
    words: ["wheat", "flour", "bread", "breadcrumb", "pasta", "noodle", "barley", "rye", "soy sauce", "beer", "couscous", "seitan", "bulgur", "semolina", "farro", "spelt", "malt"],
    safe: ["buckwheat", "almond flour", "coconut flour", "rice flour", "oat flour", "chickpea flour", "cassava flour", "tapioca flour", "corn flour", "cornflour", "quinoa flour", "sorghum flour", "teff flour", "arrowroot flour", "potato flour", "gluten-free flour", "gluten-free",
      "rice noodle", "zucchini noodle", "sweet potato noodle", "glass noodle", "shirataki noodle", "kelp noodle", "chickpea pasta", "rice pasta", "lentil pasta", "corn pasta", "gluten-free pasta",
      "corn tortilla", "rice cracker", "gluten-free bread", "tamari", "coconut aminos", "gluten-free soy sauce", "gluten-free beer"],
  },
  soy: { name: "Soy", words: ["soy", "soya", "tofu", "edamame", "tempeh", "miso", "tamari"], safe: ["soy-free", "coconut aminos"] },
  fish: {
    name: "Fish",
    words: ["salmon", "tuna", "cod", "tilapia", "anchov", "halibut", "trout", "sardine", "fish", "mahi", "snapper", "haddock", "mackerel"],
    safe: ["fish-free", "vegan fish sauce"],
  },
  shellfish: {
    name: "Shellfish",
    words: ["shrimp", "prawn", "crab", "lobster", "crawfish", "crayfish", "scampi", "clam", "mussel", "oyster", "scallop", "squid", "calamari"],
    safe: ["crabapple", "crab apple", "oyster mushroom", "oyster sauce"],
  },
  sesame: { name: "Sesame", words: ["sesame", "tahini", "benne"], safe: ["sesame-free"] },
  corn: { name: "Corn", words: ["corn", "cornstarch", "cornmeal", "polenta", "grits", "maize", "masa"], safe: ["acorn", "peppercorn", "cornish", "corn-free"] },
  mustard: { name: "Mustard", words: ["mustard"], safe: ["mustard greens"] },
  celery: { name: "Celery", words: ["celery", "celeriac"], safe: [] },
  sulfite: { name: "Sulfites", words: ["wine", "dried apricot", "sulfite", "sulphite"], safe: ["wine vinegar"] },
};

const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/** Display names of any triggers whose keywords appear in the ingredient text. */
export function flagAllergens(ingredients: string[], allergens: string[]): string[] {
  const text = " " + ingredients.join(" ").toLowerCase() + " ";
  const hits: string[] = [];
  for (const slug of allergens) {
    // A custom trigger ("mango") has no entry, so the typed name is the keyword.
    const entry = KEYWORDS[slug] ?? { name: slug, words: [slug.toLowerCase()], safe: [] };
    let hay = text;
    for (const phrase of entry.safe) hay = hay.split(phrase).join(" ");
    if (entry.words.some((w) => new RegExp("(^|[^a-z])" + esc(w)).test(hay))) hits.push(entry.name);
  }
  return hits;
}
