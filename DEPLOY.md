# AllergyFit — Deploy checklist

Everything below is code that's committed but **not yet live** on Supabase. The app
builds and runs without it; each item just unlocks a specific feature. Do them in the
Supabase dashboard for project **AllergyFit** (`aamwutlbnrkymtovkucz`).

---

## 1. Database migrations — Supabase → SQL Editor

Open each file in `supabase/migrations/`, copy the contents into the SQL Editor, and Run.

- [ ] **`005_saved_recipe_details.sql`**
  Adds `directions`, `protein`, `carbs`, `fat` columns to `saved_recipes`.
  **Unlocks:** saved recipes sync their cooking steps + macros across devices.

- [ ] **`006_anaphylaxis_severity.sql`**
  Adds the `anaphylaxis` tier to the `severity_level` enum.
  ⚠️ **Run this file BY ITSELF** — paste it alone, run it, nothing else in the query window.
  Postgres does not allow `ALTER TYPE ... ADD VALUE` to share a transaction with other statements.
  **Unlocks:** saving an allergen at the Anaphylaxis level (Mild/Moderate/Severe already work).

---

## 2. Edge Functions — Supabase → Edge Functions → (select function) → paste file → Deploy

Source lives in `supabase/functions/<name>/index.ts`.

- [ ] **`analyze-meal`**
  Haiku cost cut **+** new `estimate_only` mode.
  **Unlocks:** the "Calculate protein, carbs & fat" button on recipes (currently errors),
  and the ~5× cheaper meal logger.

- [ ] **`generate-recipe`**
  Haiku cost cut **+** allergen keyword safety-net (with one corrective retry).
  **Unlocks:** ~5× cheaper recipe + "Plan my day" generation, and the server-side trigger double-check.

- [ ] **`recipes`**
  Maps directions + macros + servings from the recipe sources.
  **Unlocks:** fresh web searches return cooking steps, full macros, and servings.

---

## 3. Google sign-in (optional — only when you want the button live)

- [ ] Supabase → Authentication → Providers → **Google**: enable, paste the Google Cloud
      OAuth **Client ID + Secret**.
- [ ] Supabase → Authentication → URL Configuration → **Redirect URLs**: add
      `allergyfit://login-callback`.
- [ ] Google Cloud Console → your OAuth client → **Authorized redirect URIs**: add
      `https://aamwutlbnrkymtovkucz.supabase.co/auth/v1/callback`.

---

## Minimum to unblock what you're using right now

1. Run **`006_anaphylaxis_severity.sql`** (by itself) → anaphylaxis level saves.
2. Redeploy **`analyze-meal`** → the "Calculate nutrition" button works.

Everything else is enhancement and can wait.
