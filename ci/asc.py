# App Store Connect from the CI, by its API (4.6), with the key in ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8: what a
# release needs, without a Mac or the website (.github/workflows/release.yml, appstore.yml; README → Releasing).
#   python3 ci/asc.py check              the app's versions and availability, and the passes: each one's versions (the
#                                        new In-App Purchase, subscription and group versions), localizations, price,
#                                        territories, and which ids the app asks for are missing. Only reads.
#   python3 ci/asc.py next-build         the next build number App Store Connect hasn't seen (the CI builds with it)
#   python3 ci/asc.py wait-build V B     until build V (B) has been processed (or fails)
#   python3 ci/asc.py prepare V [B] [--on-approval]
#                                        version V, made if no version can be edited, released by hand once approved
#                                        (with --on-approval, as soon as App Review approves it): What's New
#                                        (store/whats-new.txt), build B (else V's newest processed one), App Review's
#                                        notes (store/review-notes.txt)
#   python3 ci/asc.py screenshots        store/screenshots/ into the version that can be edited: each screenshot set
#                                        whose pictures are one of our sizes gets ours instead, six in order
#   python3 ci/asc.py submit [--go]      the version that can be edited, with each pass version waiting to go, in one
#                                        review submission (as App Review needs a new app's first passes); without
#                                        --go, only what it would send
# Never a version that's live or with App Review, and nothing outside this app.
import glob, hashlib, json, os, re, sys, time, urllib.parse, urllib.request

BUNDLE = "uk.co.thebetrayal.app"
WANT_IDS = {"uk.co.thebetrayal.app.night", "uk.co.thebetrayal.app.host"}  # what the app asks for (Model/Shop.swift)
BASE = "https://api.appstoreconnect.apple.com"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "REJECTED", "DEVELOPER_REJECTED", "METADATA_REJECTED", "INVALID_BINARY"}
GOING = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}  # a pass version that can go with the app's

_token = None
def token():
    global _token
    if not _token or _token[1] < time.time() + 60:
        import jwt
        exp = int(time.time()) + 1100
        _token = (jwt.encode({"iss": os.environ["ISSUER"], "iat": int(time.time()), "exp": exp, "aud": "appstoreconnect-v1"},
                             os.environ["P8"], algorithm="ES256", headers={"kid": os.environ["KEY_ID"], "typ": "JWT"}), exp)
    return _token[0]

def call(method, path, body=None, ok=False, **q):
    url = (path if path.startswith("http") else BASE + path) + ("?" + urllib.parse.urlencode(q) if q else "")
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, method=method,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        msg = e.read().decode()[:900]
        if ok: return {"error": e.code, "body": msg}
        sys.exit(f"{method} {path}: {e.code} {msg}")

def every(path, **q):  # every page of a list
    out, j = [], call("GET", path, limit=200, **q)
    while True:
        out += j.get("data", [])
        nxt = (j.get("links") or {}).get("next")
        if not nxt: return out
        j = call("GET", nxt)

def app_id():
    a = call("GET", "/v1/apps", **{"filter[bundleId]": BUNDLE})["data"]
    if not a: sys.exit(f"no app with bundle id {BUNDLE}")
    return a[0]["id"]

def state(v):
    return v["attributes"].get("appVersionState") or v["attributes"].get("appStoreState")

def versions(aid):
    return call("GET", f"/v1/apps/{aid}/appStoreVersions", limit=10, **{"filter[platform]": "IOS"})["data"]

def editable(aid):
    for v in versions(aid):
        if v["attributes"].get("appStoreState") in EDITABLE or v["attributes"].get("appVersionState") in EDITABLE: return v
    return None

def passes(aid):  # (kind, id, product id, state) for each In-App Purchase and subscription, and each group
    out = [("inAppPurchase", p["id"], p["attributes"]["productId"], p["attributes"]["state"]) for p in every(f"/v1/apps/{aid}/inAppPurchasesV2")]
    for g in every(f"/v1/apps/{aid}/subscriptionGroups"):
        out.append(("subscriptionGroup", g["id"], g["attributes"]["referenceName"], None))
        out += [("subscription", s["id"], s["attributes"]["productId"], s["attributes"]["state"]) for s in every(f"/v1/subscriptionGroups/{g['id']}/subscriptions")]
    return out

VERSIONS = {"inAppPurchase": "/v2/inAppPurchases/{}/versions", "subscription": "/v1/subscriptions/{}/versions", "subscriptionGroup": "/v1/subscriptionGroups/{}/versions"}
ITEM = {"inAppPurchase": ("inAppPurchaseVersion", "inAppPurchaseVersions"), "subscription": ("subscriptionVersion", "subscriptionVersions"),
        "subscriptionGroup": ("subscriptionGroupVersion", "subscriptionGroupVersions")}

def pass_versions(kind, pid):  # the new In-App Purchase, subscription and group versions, with their localizations
    j = call("GET", VERSIONS[kind].format(pid), limit=20, include="localizations")
    locs = {x["id"]: x["attributes"] for x in j.get("included", [])}
    return [(v, [locs.get(r["id"], {}) for r in (v.get("relationships", {}).get("localizations", {}).get("data") or [])]) for v in j.get("data", [])]

def territories(path):
    return len(every(path))

# ---------------------------------------------------------------------------------------------------------------
def check():
    aid = app_id()
    av = call("GET", f"/v1/apps/{aid}/appAvailabilityV2", ok=True).get("data")
    if av: print(f"the app: available in new territories {av['attributes'].get('availableInNewTerritories')}, territories {territories('/v2/appAvailabilities/' + av['id'] + '/territoryAvailabilities')}")
    for i, v in enumerate(versions(aid)[:5]):
        print(f"   version {v['attributes']['versionString']}: {state(v)}")
        # the store's links (the developer website is where AdMob looks for app-ads.txt)
        for loc in call("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"] if i < 2 else []:
            a = loc["attributes"]; print(f"      {a.get('locale')}: marketing URL {a.get('marketingUrl')}, support URL {a.get('supportUrl')}")
    found = set()
    print("\nthe passes:")
    for kind, pid, name, st in passes(aid):
        if kind != "subscriptionGroup": found.add(name)
        print(f"   {kind} {name!r}" + (f": {st}" if st else ""))
        for v, locs in pass_versions(kind, pid):
            print(f"      version {v['attributes'].get('version')}: {v['attributes'].get('state')}; " + (", ".join(f"{l.get('locale')} {l.get('name')!r}" for l in locs) or "no localizations"))
        if kind == "inAppPurchase":
            print(f"      price schedule: {'yes' if call('GET', f'/v2/inAppPurchases/{pid}/iapPriceSchedule', ok=True).get('data') else 'none'}")
            ia = call("GET", f"/v2/inAppPurchases/{pid}/inAppPurchaseAvailability", ok=True).get("data")
            print(f"      territories: {territories('/v1/inAppPurchaseAvailabilities/' + ia['id'] + '/availableTerritories') if ia else 'NONE SET'}")
        if kind == "subscription":
            print(f"      prices: {'yes' if call('GET', f'/v1/subscriptions/{pid}/prices', limit=1).get('data') else 'none'}")
            plans = call("GET", f"/v1/subscriptions/{pid}/relationships/planAvailabilities", ok=True).get("data") or []
            print("      territories: " + (", ".join(str(territories('/v1/subscriptionPlanAvailabilities/' + p['id'] + '/availableTerritories')) for p in plans) or "NONE SET"))
    print("\nthe app asks for:", ", ".join(sorted(WANT_IDS)), "· missing:", ", ".join(sorted(WANT_IDS - found)) or "none")

def next_build():
    nums = [int(b["attributes"]["version"]) for b in every("/v1/builds", **{"filter[app]": app_id(), "fields[builds]": "version"})
            if re.fullmatch(r"\d+", b["attributes"].get("version") or "")]
    print(max(nums, default=0) + 1)

def build_for(aid, v, b=None):
    q = {"filter[app]": aid, "filter[preReleaseVersion.version]": v, "limit": 50}
    if b: q["filter[version]"] = b
    bs = call("GET", "/v1/builds", **q)["data"]
    bs.sort(key=lambda x: int(x["attributes"]["version"]) if x["attributes"]["version"].isdigit() else 0, reverse=True)
    return bs

def wait_build(v, b):
    aid = app_id()
    for i in range(80):  # Apple takes minutes to list a build, then to process it
        bs = build_for(aid, v, b)
        st = bs[0]["attributes"].get("processingState") if bs else "not listed yet"
        print(f"   build {v} ({b}): {st}", flush=True)
        if st == "VALID": return
        if st in ("FAILED", "INVALID"): sys.exit(f"build {v} ({b}) is {st}")
        time.sleep(30)
    sys.exit(f"build {v} ({b}) wasn't processed in 40 minutes")

def prepare(v, b=None, on_approval=False):
    aid = app_id()
    ver = editable(aid)
    release = "AFTER_APPROVAL" if on_approval else "MANUAL"
    if ver is None:
        made = call("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions", "attributes": {"platform": "IOS", "versionString": v, "releaseType": release},
                                                              "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}}, ok=True)
        if "error" in made: sys.exit(f"couldn't make version {v} (one may still be with App Review): {made['body']}")
        ver = made["data"]; print(f"version {v}: made")
    else:
        call("PATCH", f"/v1/appStoreVersions/{ver['id']}", {"data": {"type": "appStoreVersions", "id": ver["id"], "attributes": {"versionString": v, "releaseType": release}}})
        print(f"version {ver['attributes']['versionString']} ({state(ver)})" + (f": now {v}" if ver["attributes"]["versionString"] != v else ""))
    vid = ver["id"]
    print("   released " + ("as soon as App Review approves it" if on_approval else "by hand once approved"))
    if not os.path.exists("store/whats-new.txt"):
        print("   ::warning:: no store/whats-new.txt: an update needs its What's New before it can be submitted")
    else:
        words = open("store/whats-new.txt").read().strip()
        for loc in call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]:
            r = call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": words}}}, ok=True)
            print(f"   What's New ({loc['attributes']['locale']}): " + ("set" if "error" not in r else f"not set: {r['body'][:200]} (the app's first version has none)"))
    bs = build_for(aid, v, b)
    bs = [x for x in bs if x["attributes"].get("processingState") == "VALID" and not x["attributes"].get("expired")]
    if not bs: sys.exit(f"   no processed build of {v}" + (f" numbered {b}" if b else "") + ": run the upload first")
    call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": bs[0]["id"]}})
    print(f"   build: {v} ({bs[0]['attributes']['version']})")
    rd = call("GET", f"/v1/appStoreVersions/{vid}/appStoreReviewDetail", ok=True).get("data")
    notes = open("store/review-notes.txt").read().strip()
    if rd:
        call("PATCH", f"/v1/appStoreReviewDetails/{rd['id']}", {"data": {"type": "appStoreReviewDetails", "id": rd["id"], "attributes": {"notes": notes, "demoAccountRequired": False}}})
    else:
        call("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": {"notes": notes, "demoAccountRequired": False},
                                                            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    print(f"   App Review's notes: store/review-notes.txt ({len(notes)} characters)")

def screenshots():
    from PIL import Image
    ours = {}
    for d in sorted(glob.glob("store/screenshots/*")):
        files = sorted(glob.glob(d + "/*.jpg")) + sorted(glob.glob(d + "/*.png"))
        if files: ours[Image.open(files[0]).size] = (os.path.basename(d), files)
    aid = app_id(); ver = editable(aid)
    if ver is None: sys.exit("no version that can be edited: nothing sent")
    print(f"version {ver['attributes']['versionString']} ({state(ver)})")
    done = set()
    for loc in call("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"]:
        for s in call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]:
            old = call("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"]
            sizes = {((o["attributes"].get("imageAsset") or {}).get("width"), (o["attributes"].get("imageAsset") or {}).get("height")) for o in old}
            match = next((ours[z] for z in sizes if z in ours), None)
            print(f"   {loc['attributes']['locale']} {s['attributes']['screenshotDisplayType']}: {len(old)} pictures -> {match[0] if match else 'not ours, left as it is'}")
            if not match: continue
            for o in old: call("DELETE", f"/v1/appScreenshots/{o['id']}")
            ids = []
            for f in match[1]:
                data = open(f, "rb").read()
                shot = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": os.path.basename(f), "fileSize": len(data)},
                                                                    "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": s["id"]}}}}})["data"]
                for op in shot["attributes"]["uploadOperations"]:
                    req = urllib.request.Request(op["url"], data=data[op["offset"]:op["offset"] + op["length"]], method=op["method"],
                                                 headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])})
                    with urllib.request.urlopen(req) as r: r.read()
                call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"], "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
                ids.append(shot["id"])
            call("PATCH", f"/v1/appScreenshotSets/{s['id']}/relationships/appScreenshots", {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
            done.add(match[0])
    print("   not sent (no set of that size):", ", ".join(sorted(n for n, _ in ours.values() if n not in done)) or "none")

def submit(go=False):
    aid = app_id(); ver = editable(aid)
    if ver is None: sys.exit("no version that can be edited: nothing to submit")
    vid = ver["id"]
    b = call("GET", f"/v1/appStoreVersions/{vid}/build", ok=True).get("data")
    if not b: sys.exit(f"version {ver['attributes']['versionString']} has no build: run prepare first")
    items = [("appStoreVersion", "appStoreVersions", vid, f"version {ver['attributes']['versionString']} ({b['attributes']['version']})")]
    for kind, pid, name, st in passes(aid):
        for v, _ in pass_versions(kind, pid):
            if v["attributes"].get("state") in GOING:
                rel, typ = ITEM[kind]
                items.append((rel, typ, v["id"], f"{kind} {name!r} version {v['attributes'].get('version')} ({v['attributes'].get('state')})"))
    print("to App Review, together:"); [print("   " + x[3]) for x in items]
    if not go: print("(a preview: run with --go to submit)"); return
    drafts = [r for r in every(f"/v1/apps/{aid}/reviewSubmissions", **{"filter[platform]": "IOS"}) if r["attributes"].get("state") == "READY_FOR_REVIEW"]
    sub = drafts[0] if drafts else call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                                                                                   "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]
    have = {(r.get("type"), r.get("id")) for it in every(f"/v1/reviewSubmissions/{sub['id']}/items", include="appStoreVersion,inAppPurchaseVersion,subscriptionVersion,subscriptionGroupVersion")
            for r in [d.get("data") or {} for d in it.get("relationships", {}).values()]}
    for rel, typ, iid, what in items:
        if (typ, iid) in have: print(f"   already in: {what}"); continue
        r = call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}}, rel: {"data": {"type": typ, "id": iid}}}}}, ok=True)
        print(f"   added: {what}" if "error" not in r else f"   not added: {what}: {r['body'][:300]}")
    r = call("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}}, ok=True)
    print("submitted to App Review" if "error" not in r else f"not submitted: {r['body']}")
    if "error" in r: sys.exit(1)

if __name__ == "__main__":
    a = sys.argv[1:]
    if not a: sys.exit(__doc__ or "check | next-build | wait-build V B | prepare V [B] [--on-approval] | screenshots | submit [--go]")
    cmd = a[0]
    if cmd == "check": check()
    elif cmd == "next-build": next_build()
    elif cmd == "wait-build": wait_build(a[1], a[2])
    elif cmd == "prepare":
        p = [x for x in a[1:] if not x.startswith("--")]
        prepare(p[0], p[1] if len(p) > 1 else None, "--on-approval" in a)
    elif cmd == "screenshots": screenshots()
    elif cmd == "submit": submit("--go" in a)
    else: sys.exit("check | next-build | wait-build V B | prepare V [B] [--on-approval] | screenshots | submit [--go]")

# (checked against App Store Connect on 2026-11-16)
