# The passes put up for review by App Store Connect's API, to go with the app's version: the Night Pass (an In-App
# Purchase) and the Host Pass (a subscription), each only if it's Ready to Submit. A new app's first ones are reviewed
# with a version, so Apple may hold them for the version's submission, or refuse here and want the website (the
# version page's In-App Purchases and Subscriptions): either way this prints what Apple said, and each pass's state
# before and after. Run by .github/workflows/asc-iaps.yml with the upload's API key.
import json, os, sys, time, urllib.parse, urllib.request
import jwt

BUNDLE = "uk.co.thebetrayal.app"
BASE = "https://api.appstoreconnect.apple.com"
token = jwt.encode({"iss": os.environ["ISSUER"], "iat": int(time.time()), "exp": int(time.time()) + 1100, "aud": "appstoreconnect-v1"},
                   os.environ["P8"], algorithm="ES256", headers={"kid": os.environ["KEY_ID"], "typ": "JWT"})

def call(method, path, body=None, **q):
    url = BASE + path + ("?" + urllib.parse.urlencode(q) if q else "")
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method,
                                 headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read(); return True, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return False, {"status": e.code, "body": e.read().decode()[:800]}

def must(method, path, **q):
    ok, j = call(method, path, **q)
    if not ok: sys.exit(f"{method} {path}: {j}")
    return j

aid = must("GET", "/v1/apps", **{"filter[bundleId]": BUNDLE})["data"][0]["id"]
for v in must("GET", f"/v1/apps/{aid}/appStoreVersions", limit=5)["data"]:
    print(f"version {v['attributes']['versionString']}: {v['attributes'].get('appStoreState')}")

def passes():
    out = [("iap", p["id"], p["attributes"]["productId"], p["attributes"]["state"]) for p in must("GET", f"/v1/apps/{aid}/inAppPurchasesV2", limit=20)["data"]]
    for g in must("GET", f"/v1/apps/{aid}/subscriptionGroups", limit=10)["data"]:
        out += [("sub", s["id"], s["attributes"]["productId"], s["attributes"]["state"], g["id"]) for s in must("GET", f"/v1/subscriptionGroups/{g['id']}/subscriptions", limit=10)["data"]]
    return out

before = passes()
print("\nbefore:"); [print(f"   {x[2]}: {x[3]}") for x in before]
for x in before:
    if x[3] != "READY_TO_SUBMIT": print(f"\n{x[2]}: {x[3]}, left as it is"); continue
    if x[0] == "iap":
        ok, j = call("POST", "/v1/inAppPurchaseSubmissions", {"data": {"type": "inAppPurchaseSubmissions",
                     "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": x[1]}}}}})
    else:
        ok, j = call("POST", "/v1/subscriptionSubmissions", {"data": {"type": "subscriptionSubmissions",
                     "relationships": {"subscription": {"data": {"type": "subscriptions", "id": x[1]}}}}})
        if not ok and "group" in json.dumps(j).lower():  # (a group's first may go as the group)
            ok, j = call("POST", "/v1/subscriptionGroupSubmissions", {"data": {"type": "subscriptionGroupSubmissions",
                         "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": x[4]}}}}})
    print(f"\n{x[2]}: {'put up for review' if ok else 'Apple said no'}" + ("" if ok else f": {j['status']} {j['body']}"))

time.sleep(5)
print("\nafter:"); [print(f"   {x[2]}: {x[3]}") for x in passes()]
