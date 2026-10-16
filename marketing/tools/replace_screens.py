"""Back up, then replace, the 6.9-inch iPhone screenshots for every locale."""
import asc, hashlib, os, sys, urllib.request
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "screenshots", "out")
BACKUP = os.path.join(ROOT, "screenshots", "backup-v1")
TYPE = "APP_IPHONE_67"

def delete(path): return asc._req("DELETE", path)

locs = asc.get(f"appStoreVersions/{asc.VERSION_ID}/appStoreVersionLocalizations?limit=50")["data"]
for loc in locs:
    code = loc["attributes"]["locale"]
    src = os.path.join(OUT, code)
    if not os.path.isdir(src):
        print("skip", code); continue
    sets = asc.get(f"appStoreVersionLocalizations/{loc['id']}/appScreenshotSets?limit=20")["data"]
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == TYPE), None)
    if sset is None:
        sset = asc.post("appScreenshotSets", {"data": {"type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": TYPE},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
    old = asc.get(f"appScreenshotSets/{sset['id']}/appScreenshots?limit=20")["data"]
    os.makedirs(os.path.join(BACKUP, code), exist_ok=True)
    for i, shot in enumerate(old, 1):
        asset = shot["attributes"].get("imageAsset") or {}
        if asset.get("templateUrl"):
            url = asset["templateUrl"].replace("{w}", str(asset["width"])).replace("{h}", str(asset["height"])).replace("{f}", "png")
            urllib.request.urlretrieve(url, os.path.join(BACKUP, code, f"{i:02d}.png"))
    for shot in old:
        delete(f"appScreenshots/{shot['id']}")
    for name in sorted(os.listdir(src)):
        data = open(os.path.join(src, name), "rb").read()
        res = asc.post("appScreenshots", {"data": {"type": "appScreenshots",
            "attributes": {"fileName": f"{code}-{name}", "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
        for op in res["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]: op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                         headers={h["name"]: h["value"] for h in op["requestHeaders"]})
            urllib.request.urlopen(req).read()
        asc.patch(f"appScreenshots/{res['id']}", {"data": {"type": "appScreenshots", "id": res["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(code, f"backed up {len(old)}, uploaded {len(os.listdir(src))}")
