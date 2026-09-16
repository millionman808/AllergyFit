# SafeFuel marketing assets

Kept in the repo so they survive `/tmp` cleanup (the first set didn't).

- `site/` — safefuel-app.web.app (and the legacy allergyfit-app.web.app, same content).
  Deploy: `cd marketing/site && firebase deploy --only hosting`
- `listing/current.json` — App Store Connect text as last pulled (6 locales).
- `screenshots/current-en-US/` — the 7 live 6.9" panels, pulled from ASC.
  The compositor that made them was lost; regenerate from scratch if they change.
- `tools/asc.py` — App Store Connect API client (`get/post/patch`), key 77WKTNQ9N4.
  `python3 -m venv .venv && .venv/bin/pip install pyjwt cryptography pillow`

App Store name: "SafeFuel: Allergy-Safe Macros" / subtitle "Calorie Tracker for Athletes".
Bundle ID stays com.elischafer.allergyfit — never user-visible.
