# The version that can still be edited, made ready to submit by App Store Connect's API, without submitting it: its
# version number (VERSION, 1.1), its build (BUILD, 6: processed, not expired), and App Review's notes
# (store/review-notes.txt). Then what's left by hand: the passes attached to the version, App Privacy, submitting.
# Run by .github/workflows/asc-prepare.yml with the upload's API key (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8).
import json, os, sys, time, urllib.parse, urllib.request
import jwt

BUNDLE = "uk.co.thebetrayal.app"
BASE = "https://api.appstoreconnect.apple.com"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
WANT, BUILD = os.environ.get("VERSION", "1.1"), os.environ.get("BUILD", "6")
NOTES = open("store/review-notes.txt").read().strip()
token = jwt.encode({"iss": os.environ["ISSUER"], "iat": int(time.time()), "exp": int(time.time()) + 1100, "aud": "appstoreconnect-v1"},
                   os.environ["P8"], algorithm="ES256", headers={"kid": os.environ["KEY_ID"], "typ": "JWT"})

def call(method, path, body=None, **q):
    url = BASE + path + ("?" + urllib.parse.urlencode(q) if q else "")
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method,
                                 headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read(); return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path}: {e.code} {e.read().decode()[:800]}")

app = call("GET", "/v1/apps", **{"filter[bundleId]": BUNDLE})["data"][0]; aid = app["id"]
vs = call("GET", f"/v1/apps/{aid}/appStoreVersions", limit=10)["data"]
ed = [v for v in vs if v["attributes"].get("appStoreState") in EDITABLE]
if not ed: sys.exit("no version that can be edited: nothing changed")
ver = ed[0]; vid = ver["id"]
print(f"the version: {ver['attributes']['versionString']} ({ver['attributes']['appStoreState']})")

if ver["attributes"]["versionString"] != WANT:
    call("PATCH", f"/v1/appStoreVersions/{vid}", {"data": {"type": "appStoreVersions", "id": vid, "attributes": {"versionString": WANT}}})
    print(f"   version number: {ver['attributes']['versionString']} -> {WANT}")
else:
    print(f"   version number: already {WANT}")

bs = call("GET", "/v1/builds", **{"filter[app]": aid, "filter[version]": BUILD, "filter[preReleaseVersion.version]": WANT, "limit": 5})["data"]
if not bs: sys.exit(f"no build {WANT} ({BUILD}) in App Store Connect")
b = bs[0]["attributes"]
print(f"   build {WANT} ({BUILD}): {b.get('processingState')}, expired {b.get('expired')}, uses non-exempt encryption {b.get('usesNonExemptEncryption')}")
if b.get("processingState") != "VALID" or b.get("expired"): sys.exit("   that build can't be chosen yet")
call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": bs[0]["id"]}})
print(f"   build: {WANT} ({BUILD}) chosen")

rd = call("GET", f"/v1/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
if rd:
    call("PATCH", f"/v1/appStoreReviewDetails/{rd['id']}", {"data": {"type": "appStoreReviewDetails", "id": rd["id"],
                                                                     "attributes": {"notes": NOTES, "demoAccountRequired": False}}})
    print(f"   App Review's notes: replaced ({len(NOTES)} characters, Your passes first)")
else:
    print("   ::warning:: no App Review details on this version: paste store/review-notes.txt into App Review Information by hand")

print("\nthe screenshots:")
for loc in call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]:
    for st in call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]:
        shots = call("GET", f"/v1/appScreenshotSets/{st['id']}/appScreenshots")["data"]
        states = [((x["attributes"].get("assetDeliveryState") or {}).get("state")) for x in shots]
        print(f"   {loc['attributes']['locale']} {st['attributes']['screenshotDisplayType']}: {len(shots)}, " + ", ".join(f"{states.count(k)} {k}" for k in sorted(set(states), key=str)))

print("\nthe passes:")
for p in call("GET", f"/v1/apps/{aid}/inAppPurchasesV2", limit=20)["data"]:
    print(f"   {p['attributes']['productId']}: {p['attributes']['state']}")
for g in call("GET", f"/v1/apps/{aid}/subscriptionGroups", limit=10)["data"]:
    for s in call("GET", f"/v1/subscriptionGroups/{g['id']}/subscriptions", limit=10)["data"]:
        print(f"   {s['attributes']['productId']}: {s['attributes']['state']}")
print("\nleft by hand: attach both passes under In-App Purchases and Subscriptions on the version, App Privacy (Email Address,"
      " Customer Support), the reply to App Review, and Submit, once the Paid Apps Agreement is Active")
