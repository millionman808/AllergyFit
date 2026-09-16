#!/bin/sh
# Inline _shared/*.ts into each function so the single-file dashboard editor
# can take it. Output: build/functions/<name>/index.ts (never commit these).
set -e
cd "$(dirname "$0")"
mkdir -p ../build/functions
for fn in generate-recipe recipes; do
  mkdir -p "../build/functions/$fn"
  python3 - "$fn" <<PY
import sys,re,pathlib
fn=sys.argv[1]
src=pathlib.Path(f"functions/{fn}/index.ts").read_text()
shared=pathlib.Path("functions/_shared/allergens.ts").read_text().replace("export ","")
out=src.replace('import { flagAllergens } from "../_shared/allergens.ts";', "// ---- inlined from _shared/allergens.ts (see supabase/bundle.sh) ----\n"+shared+"\n// ---- end shared ----")
pathlib.Path(f"../build/functions/{fn}/index.ts").write_text(out)
print(fn, "->", len(out.splitlines()), "lines")
PY
done
