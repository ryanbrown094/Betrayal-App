# What App Store Connect has for the app's passes, read-only, for when the app is given no products (Your passes:
# "Passes aren't available right now"): each In-App Purchase's and subscription's product id, state, localizations,
# price, review screenshot and territories, the subscription group's localizations, the app's availability, and its
# versions. Run by .github/workflows/asc-check.yml with the API key in ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8; it
# only reads (GET), and prints no key.
import json, os, sys, time, urllib.parse, urllib.request
import jwt

APP_IDS = {"uk.co.thebetrayal.app.night", "uk.co.thebetrayal.app.host"}  # what the app asks for (Model/Shop.swift)
BUNDLE = "uk.co.thebetrayal.app"
BASE = "https://api.appstoreconnect.apple.com"
token = jwt.encode({"iss": os.environ["ISSUER"], "iat": int(time.time()), "exp": int(time.time()) + 1100, "aud": "appstoreconnect-v1"},
                   os.environ["P8"], algorithm="ES256", headers={"kid": os.environ["KEY_ID"], "typ": "JWT"})

def get(path, **q):
    url = BASE + path + ("?" + urllib.parse.urlencode(q) if q else "")
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    try:
        with urllib.request.urlopen(req) as r: return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:300]
        print(f"   ({e.code} for {path}: {body})"); return {"data": []}

def territories(path):
    n, nxt, first = 0, path, True
    while nxt and n < 400:
        j = get(nxt, limit=200) if first else get(nxt.replace(BASE, ""))
        first = False
        n += len(j.get("data", [])); nxt = (j.get("links") or {}).get("next")
    return n

apps = get("/v1/apps", **{"filter[bundleId]": BUNDLE})["data"]
if not apps: sys.exit(f"no app with bundle id {BUNDLE}")
app = apps[0]; aid = app["id"]
print(f"app: {app['attributes']['name']} ({BUNDLE}), id {aid}, primary locale {app['attributes'].get('primaryLocale')}")

av = get(f"/v1/apps/{aid}/appAvailabilityV2").get("data") or {}
if av:
    n = territories("/v2/appAvailabilities/" + av["id"] + "/territoryAvailabilities")
    print(f"app availability: available in new territories {av['attributes'].get('availableInNewTerritories')}; territories: {n}")

print("\nversions:")
for v in get(f"/v1/apps/{aid}/appStoreVersions", limit=5)["data"]:
    a = v["attributes"]; print(f"   {a.get('platform')} {a.get('versionString')}: {a.get('appStoreState') or a.get('appVersionState')}")

found = set()
print("\nIn-App Purchases:")
for p in get(f"/v1/apps/{aid}/inAppPurchasesV2", limit=50)["data"]:
    a, pid = p["attributes"], p["id"]; found.add(a.get("productId"))
    print(f"   {a.get('productId')!r} ({a.get('name')}, {a.get('inAppPurchaseType')}): state {a.get('state')}")
    for l in get(f"/v2/inAppPurchases/{pid}/inAppPurchaseLocalizations")["data"]:
        la = l["attributes"]; print(f"      localization {la.get('locale')}: {la.get('name')!r}, state {la.get('state')}")
    shot = get(f"/v2/inAppPurchases/{pid}/appStoreReviewScreenshot").get("data")
    print(f"      review screenshot: {'yes, ' + str((shot.get('attributes') or {}).get('assetDeliveryState', {}).get('state')) if shot else 'none'}")
    ps = get(f"/v2/inAppPurchases/{pid}/iapPriceSchedule").get("data")
    print(f"      price schedule: {'yes' if ps else 'none'}")
    ia = get(f"/v2/inAppPurchases/{pid}/inAppPurchaseAvailability").get("data")
    if ia:
        n = territories("/v1/inAppPurchaseAvailabilities/" + ia["id"] + "/availableTerritories")
        print(f"      availability: new territories {ia['attributes'].get('availableInNewTerritories')}, territories {n}")
    else: print("      availability: NONE SET")

print("\nSubscriptions:")
for g in get(f"/v1/apps/{aid}/subscriptionGroups", limit=20)["data"]:
    print(f"   group {g['attributes'].get('referenceName')!r}")
    for l in get(f"/v1/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations")["data"]:
        la = l["attributes"]; print(f"      group localization {la.get('locale')}: {la.get('name')!r}, state {la.get('state')}")
    for s in get(f"/v1/subscriptionGroups/{g['id']}/subscriptions", limit=20)["data"]:
        a, sid = s["attributes"], s["id"]; found.add(a.get("productId"))
        print(f"   {a.get('productId')!r} ({a.get('name')}, {a.get('subscriptionPeriod')}): state {a.get('state')}")
        for l in get(f"/v1/subscriptions/{sid}/subscriptionLocalizations")["data"]:
            la = l["attributes"]; print(f"      localization {la.get('locale')}: {la.get('name')!r}, state {la.get('state')}")
        shot = get(f"/v1/subscriptions/{sid}/appStoreReviewScreenshot").get("data")
        print(f"      review screenshot: {'yes' if shot else 'none'}")
        pr = get(f"/v1/subscriptions/{sid}/prices", limit=3)["data"]
        print(f"      prices: {'yes' if pr else 'none'}")
        sa = get(f"/v1/subscriptions/{sid}/subscriptionAvailability").get("data")
        if sa:
            n = territories("/v1/subscriptionAvailabilities/" + sa["id"] + "/availableTerritories")
            print(f"      availability: new territories {sa['attributes'].get('availableInNewTerritories')}, territories {n}")
        else: print("      availability: NONE SET")

print("\nthe app asks for:", ", ".join(sorted(APP_IDS)))
print("missing from App Store Connect:", ", ".join(sorted(APP_IDS - found)) or "none")
print("in App Store Connect but not asked for:", ", ".join(sorted(x for x in found - APP_IDS if x)) or "none")

# (run on 2026-11-09)
