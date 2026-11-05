# The CI's simulators (.github/workflows/ios.yml, ci/shots.sh): the device types to try making, on which runtimes, in
# order, one "TYPE RUNTIME" a line. Runtimes newest first; where a runtime lists the types it makes, only those, so no
# time goes on refusals (Xcode 27.1's iOS runtime makes only the iPhone Duo).
#   python3 ci/device.py big-iphone    the biggest one-screen iPhone (a Pro Max: the App Store's 6.9" pictures)
#   python3 ci/device.py SUBSTRING     a type whose identifier has it (iPhone-Duo, iPad-Pro-13)
import json, re, subprocess, sys

def j(what):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", what, "-j"]))

want = sys.argv[1]
rts = sorted((r for r in j("runtimes")["runtimes"] if ".iOS-" in r["identifier"] and r["isAvailable"]),
             key=lambda r: [int(n) for n in r["version"].split(".")], reverse=True)
types = j("devicetypes")["devicetypes"]
if want == "big-iphone":
    num = lambda n: int((re.search(r"iPhone (\d+)", n) or [0, 0])[1])
    ts = sorted((t for t in types if t["name"].startswith("iPhone") and "Duo" not in t["name"]),
                key=lambda t: ("Pro Max" in t["name"], num(t["name"])), reverse=True)
else:
    ts = [t for t in types if want in t["identifier"]]
for r in rts:
    makes = {t["identifier"] for t in r["supportedDeviceTypes"]} if r.get("supportedDeviceTypes") else None
    for t in ts:
        if makes is None or t["identifier"] in makes:
            print(t["identifier"], r["identifier"])
