# The App Store's screenshots, sent to App Store Connect (store/screenshots/, made by store/compose.py): for the app's
# version that can still be edited (never one live, in review or waiting for it), in each of its localizations, each
# screenshot set whose pictures are one of our sizes gets ours instead, six in order. A set is matched by the size of
# the pictures already in it, so no display type is guessed (the iPhone Duo's is new). Run by
# .github/workflows/asc-screenshots.yml with the upload's API key (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8).
import glob, hashlib, json, os, sys, time, urllib.parse, urllib.request
import jwt
from PIL import Image

BUNDLE = "uk.co.thebetrayal.app"
BASE = "https://api.appstoreconnect.apple.com"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
OURS = {}
for d in sorted(glob.glob("store/screenshots/*")):
    files = sorted(glob.glob(d + "/*.jpg")) + sorted(glob.glob(d + "/*.png"))
    if files: OURS[Image.open(files[0]).size] = (os.path.basename(d), files)

token = jwt.encode({"iss": os.environ["ISSUER"], "iat": int(time.time()), "exp": int(time.time()) + 1100, "aud": "appstoreconnect-v1"},
                   os.environ["P8"], algorithm="ES256", headers={"kid": os.environ["KEY_ID"], "typ": "JWT"})

def call(method, path, body=None, **q):
    url = (path if path.startswith("http") else BASE + path) + ("?" + urllib.parse.urlencode(q) if q else "")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path}: {e.code} {e.read().decode()[:600]}")

app = call("GET", "/v1/apps", **{"filter[bundleId]": BUNDLE})["data"][0]
versions = call("GET", f"/v1/apps/{app['id']}/appStoreVersions", limit=10)["data"]
editable = [v for v in versions if (v["attributes"].get("appStoreState") or v["attributes"].get("appVersionState")) in EDITABLE]
for v in versions: print(f"version {v['attributes']['versionString']}: {v['attributes'].get('appStoreState')}")
if not editable: sys.exit("no version that can be edited: nothing sent")
ver = editable[0]
print(f"sending to version {ver['attributes']['versionString']} ({ver['attributes'].get('appStoreState')})")
print("ours:", {f"{w}x{h}": name for (w, h), (name, _) in OURS.items()})

def upload(set_id, path):
    data = open(path, "rb").read()
    shot = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
                                                        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"], headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])})
        with urllib.request.urlopen(req) as r: r.read()
    call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
                                                               "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return shot["id"]

done = set()
for loc in call("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"]:
    print(f"\nlocalization {loc['attributes']['locale']}:")
    for s in call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]:
        kind = s["attributes"]["screenshotDisplayType"]
        old = call("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"]
        sizes = {((o["attributes"].get("imageAsset") or {}).get("width"), (o["attributes"].get("imageAsset") or {}).get("height")) for o in old}
        match = next((OURS[z] for z in sizes if z in OURS), None)
        print(f"   {kind}: {len(old)} pictures, sizes {sorted(sizes)} -> {match[0] if match else 'not ours, left as it is'}")
        if not match: continue
        for o in old: call("DELETE", f"/v1/appScreenshots/{o['id']}")
        ids = [upload(s["id"], f) for f in match[1]]
        call("PATCH", f"/v1/appScreenshotSets/{s['id']}/relationships/appScreenshots", {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
        for i in ids:  # Apple processes each picture: wait for it
            for _ in range(60):
                st = ((call("GET", f"/v1/appScreenshots/{i}")["data"]["attributes"].get("assetDeliveryState") or {}).get("state"))
                if st in ("COMPLETE", "FAILED"): break
                time.sleep(3)
            if st != "COMPLETE": print(f"      ::warning:: a picture is {st}")
        print(f"      sent {len(ids)}: " + ", ".join(os.path.basename(f) for f in match[1]))
        done.add(match[0])

missing = sorted(name for name, _ in OURS.values() if name not in done)
print("\nnot sent (no set of that size on the version: add one picture there by hand, then run this again):", ", ".join(missing) or "none")

# (sent on 2026-11-09)
