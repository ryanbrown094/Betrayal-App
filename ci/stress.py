# Stress: a whole Table of scripted phones against a Worker, as a party plays it on one Wi-Fi: every phone polls as the
# app does (every 1.2 s, ?v=&me=), answers, votes and chooses at night, and whoever holds the host's phone moves the
# game on. On top, the night's trouble (--chaos): phones going quiet for a while (locked, in a pocket), a guest losing
# their place and asking back in by name, the host's phone dying and the table letting the host back in, the host
# handing over to someone else, a guest taken out mid-game, and every phone voting at the same instant. A TV polls too.
# It checks, all the way: no server errors, no phone ever sees a role it shouldn't (only the Forsworn see each other;
# a role shows when its player is out), every phone keeps its place, nothing waits for ever, and the game ends.
# With --test (the master code's test game: ten-second clocks, bots filling the first seats), --launch opens a TV on the
# Table and --shot photographs it at each new screen, as ci/drive.py does for a phone.
#   python3 ci/stress.py http://127.0.0.1:8790 --players 24 --chaos
import argparse, json, random, statistics, subprocess, sys, threading, time, urllib.error, urllib.request, collections

ap = argparse.ArgumentParser()
ap.add_argument("base")
ap.add_argument("--players", type=int, default=12)
ap.add_argument("--chaos", action="store_true", help="the night's trouble: quiet phones, lost places, the host's phone dying, a hand-over")
ap.add_argument("--master", default="", help="the master code: a test game (ten-second clocks) instead of the app's free game")
ap.add_argument("--limit", type=float, default=3600, help="seconds before giving up")
ap.add_argument("--stall", type=float, default=300, help="seconds on one screen that count as stuck")
ap.add_argument("--seed", type=int, default=None)
ap.add_argument("--test", action="store_true", help="with --master: a test game (ten-second clocks; bots take the first seats)")
ap.add_argument("--launch", default="", help="command to open a TV on the Table; {room} is filled in")
ap.add_argument("--shot", default="", help="command to photograph the TV; {name} is filled in")
a = ap.parse_args()
R = random.Random(a.seed)
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({})) # a local Worker, never the proxy

NAMES = ["Ryan", "Annie", "Tom", "Sophie", "Marcus", "Priya", "Jess", "Oliver", "Hannah", "Dev", "Zoë", "Bartholomew", "D'Arcy", "José",
         "Mo", "Siobhan", "Ffion", "Olu", "Grace", "Hamish", "Ines", "Jun", "Keeley", "Luca", "Niamh", "Wren", "Yusuf", "Kit"]
lock = threading.Lock()
stats = collections.Counter()
lat = collections.defaultdict(list)
problems = []          # (seconds, what)
truth = {}             # player id -> role, as each phone learns its own
out_ids = set()        # players whose role the table has been shown (exiled, dead at the end)
t0 = time.time()
over = threading.Event()

def note(what):
    with lock:
        if len(problems) < 400: problems.append((round(time.time() - t0, 1), what))
    print(f"{time.time() - t0:7.1f}s  !! {what}", flush=True)

def call(path, body=None, tok=None, kind=None):
    req = urllib.request.Request(a.base + path, method="POST" if body is not None else "GET", data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json", **({"X-Tok": tok} if tok else {})})
    st = time.time()
    try:
        with OPENER.open(req, timeout=20) as r: code, raw = r.status, r.read()
    except urllib.error.HTTPError as e: code, raw = e.code, e.read()
    except Exception as e:
        note(f"network: {path} {e}"); return 0, {}
    with lock:
        lat[kind or path.split("?")[0].rsplit("/", 1)[-1]].append(time.time() - st); stats[f"http {code}"] += 1
    if code >= 500: note(f"server error {code} on {path}: {raw[:200]!r}")
    try: return code, json.loads(raw or b"{}")
    except Exception: note(f"not JSON from {path}: {raw[:120]!r}"); return code, {}

# what a view may show: a role only once its player is out (exiled and shown, or the end), allies only to the Forsworn
def check_view(v, who, my_role):
    if not v: return
    for p in v.get("players", []):
        if p.get("role") and v.get("phase") not in ("end", "unmask") and p.get("alive"):  # (the unmasking shows everyone left)
            note(f"{who} sees the role of {p['name']}, who is still in ({v['phase']})")
    me = v.get("me") or {}
    if me.get("allies") is not None and my_role != "f": note(f"{who} (Loyal) was told who the Forsworn are")
    if who == "TV" and me: note("the TV has a player's view")

class Phone(threading.Thread):
    def __init__(self, room, name, tok=None):
        super().__init__(daemon=True)
        self.room, self.name, self.tok, self.v, self.pid, self.role = room, name, tok, None, None, None
        self.quiet_until, self.lost, self.req, self.removed, self.seen_end = 0, False, None, False, False
        self.last_act = {}
    def path(self, p): return f"/api/g/{self.room}/{p}"
    def act(self, x, why=None):
        code, j = call(self.path("m/act"), x, self.tok, kind="act")
        with lock: stats["act " + (x.get("a") + ("." + str(x.get("v")) if x.get("a") == "tool" else ""))] += 1
        if j.get("lost"):
            if not self.removed: note(f"{self.name} lost its place on {x}")
            self.tok = None
        elif j.get("error"):
            with lock: stats["refused"] += 1
        if j.get("view"): self.take(j)
        return j
    def take(self, j):
        v = j.get("view")
        if not v: return
        self.v = v; me = v.get("me")
        if self.tok and not me and not self.removed:
            note(f"{self.name} holds a token the Table no longer knows ({v.get('phase')})"); self.tok = None; return
        if me:
            self.pid = me["id"]
            if me.get("role"):
                self.role = me["role"]
                with lock: truth[self.pid] = me["role"]
        check_view(v, self.name, self.role)
        if j.get("rejoin") and me and not self.lost: self.let_in(j["rejoin"])
    def let_in(self, reqs):
        for r in reqs:
            if self.last_act.get("letin" + r["id"], 0) > time.time() - 5: continue
            self.last_act["letin" + r["id"]] = time.time()
            j = self.act({"a": "letin", "v": r["id"]})
            if not j.get("error"): print(f"{time.time() - t0:7.1f}s  {self.name} let {r['name']} back in", flush=True)
    def poll(self):
        if self.req:
            code, j = call(self.path("m/join"), {"req": self.req}, kind="join-wait")
            if j.get("tok"):
                self.tok, self.req, self.lost = j["tok"], None, False
                print(f"{time.time() - t0:7.1f}s  {self.name} is back in", flush=True)
            elif j.get("gone"): note(f"{self.name}'s request to come back was lost: {j}"); self.req = None
            return
        if not self.tok: return
        q = f"m?v={self.v['ver'] if self.v else ''}&me={self.pid or ''}"
        code, j = call(self.path(q), tok=self.tok, kind="poll")
        if j.get("same"):
            if j.get("rejoin") and not self.lost: self.let_in(j["rejoin"])
            return
        self.take(j)
    def lose_place(self):
        # the app on a new phone (or reinstalled): no token, so it asks back in by name and waits for someone to let it in
        self.lost, self.tok, self.v = True, None, None
        code, j = call(self.path("m/join"), {"name": self.name}, kind="join")
        if j.get("req"): self.req = j["req"]; print(f"{time.time() - t0:7.1f}s  {self.name} asks back in", flush=True)
        else: note(f"{self.name} couldn't ask back in: {j}")
    def run(self):
        while not over.is_set():
            if time.time() < self.quiet_until or self.removed: time.sleep(0.5); continue
            try:
                self.poll()
                if self.v and self.tok: self.play()
            except Exception as e: note(f"{self.name}: {type(e).__name__} {e}")
            if self.v and self.v.get("phase") == "end": self.seen_end = True
            time.sleep(1.2 + R.random() * 0.2)
    def once(self, key, delay=0.0):
        # each choice is made once per screen, a moment after it appears (as a person would)
        k = key + "|" + str(self.v.get("ver"))
        first = self.last_act.setdefault("seen" + key, time.time())
        if self.last_act.get("did") == k or time.time() - first < delay: return False
        self.last_act["did"] = k; self.last_act.pop("seen" + key, None); return True
    def play(self):
        v, me = self.v, self.v.get("me") or {}
        ph, t = v["phase"], v.get("trial") or {}
        it = t.get("item") or {}
        host = me.get("director")
        alive = me.get("alive")
        others = [p for p in v["players"] if p["alive"] and p["id"] != me.get("id")]
        if ph == "oath" and not me.get("optIn") and self.once("oath", R.uniform(1, 6)): self.act({"a": "optin", "v": R.choice(["yes", "no", "any", "any"])})
        elif ph == "roles" and not me.get("acked") and self.once("roles", R.uniform(1, 8)): self.act({"a": "ack"})
        elif ph == "trial" and it.get("stage") == "open" and alive and it.get("mine") is None and self.once("ans" + str(t.get("i")) + it.get("k", ""), R.uniform(1, 5)):
            k = it.get("k")
            ans = {"rps": R.choice(["rock", "paper", "scissors"]), "truths": R.choice([1, 2, 3]), "tempt": R.choice(["purse", "pass"]),
                   "number": str(R.randint(1, 2000)), "hilo": R.choice(["higher", "lower"]), "snap": "tap"}.get(k, R.choice(["Paris", "42", "a", "B", "the moon"]))
            if k == "truths" and it.get("teller") == me.get("id"): self.act({"a": "lie", "v": R.choice([1, 2, 3])}); self.act({"a": "told"})
            elif k == "actor" and it.get("actor") == me.get("id"): self.act({"a": "guess", "v": R.choice(others)["id"] if others else "none"})
            elif k == "survive": self.act({"a": "out"})
            else: self.act({"a": "ans", "v": ans})
        elif ph == "trial" and it.get("k") == "truths" and it.get("stage") == "prep" and it.get("teller") == me.get("id") and self.once("lie", 2):
            self.act({"a": "lie", "v": R.choice([1, 2, 3])}); self.act({"a": "told"})
        elif ph == "vote" and not (v.get("vote") or {}).get("mine") and others and self.once("ballot", R.uniform(1, 6)):
            vt = v["vote"]; c = [p for p in others if p["id"] != vt.get("immune") and (not vt.get("revote") or p["id"] in vt["revote"])]
            if c: self.act({"a": "ballot", "v": R.choice(c)["id"]})
        elif ph == "reveal" and (v.get("reveal") or {}).get("id") == me.get("id") and me.get("words") == "" and self.once("words", 3):
            self.act({"a": "words", "v": R.choice(["It wasn't me.", "Trust Marcus. Never Priya.", "🙃", "x" * 200])})
        elif ph == "night" and alive and not (v.get("night") or {}).get("done") and self.once("night", R.uniform(1, 6)):
            if me.get("role") == "f":
                if me.get("targets"): self.act({"a": "pick", "v": R.choice(me["targets"])})
                if me.get("whisperSay") and R.random() < 0.5: self.act({"a": "whisper", "v": R.randint(0, len(me["whisperSay"]) - 1)})
            else: self.act({"a": "sleep"})
        elif ph == "trust" and alive and not (v.get("trust") or {}).get("mine") and not (v.get("trust") or {}).get("result") and self.once("trust", R.uniform(1, 5)):
            self.act({"a": "trust", "v": R.choice(["trust", "doubt"])})
        elif ph == "honour" and me.get("role") == "f" and alive and not (v.get("honour") or {}).get("mine") and self.once("honour", 2):
            self.act({"a": "honour", "v": R.choice(["honour", "betray"])})
        if ph in ("talk", "vote") and me.get("crown") and R.random() < 0.3 and self.once("crown", 2): self.act({"a": "crown"})
        if host: self.drive(v, me, ph, t, it)
    def drive(self, v, me, ph, t, it):
        # the host moves the night on, at a party's pace but no slower than the screens allow
        if ph == "lobby":
            if len(v["players"]) >= a.players and self.once("start", 2): self.act({"a": "start"})
        elif ph == "oath" and self.once("deal", 25): self.act({"a": "tool", "v": "deal"})      # someone never swore: the host deals
        elif ph == "roles" and self.once("begin", 25): self.act({"a": "tool", "v": "begin"})   # someone never looked: the host begins
        elif ph == "day" and self.once("next", R.uniform(2, 6)): self.act({"a": "next"})
        elif ph == "break" and self.once("brk", 5): self.act({"a": "brkEnd"})
        elif ph == "trial":
            if t.get("stage") == "done" and self.once("cont", 4): self.act({"a": "cont"})
            elif t.get("stage") == "intro" and self.once("intro", 4): self.act({"a": "tool", "v": "skip"})
            elif it.get("stage") in ("open", "study", "prep", "blank") and self.once("skip" + str(t.get("i")), 12): self.act({"a": "tool", "v": "skip"})
        elif ph == "talk" and self.once("voteNow", 8): self.act({"a": "tool", "v": "voteNow"})
        elif ph == "vote" and self.once("closeVote", 30): self.act({"a": "tool", "v": "closeVote"})
        elif ph == "reveal" and ((v.get("reveal") or {}).get("role") or (v.get("reveal") or {}).get("secret")) and self.once("rev", 4): self.act({"a": "cont"})
        elif ph == "night" and self.once("dawnNow", 40): self.act({"a": "tool", "v": "dawnNow"})
        elif ph == "dawn" and self.once("dawn" + str((v.get("dawn") or {}).get("revealed")), 4): self.act({"a": "cont"})

def tv(room):
    last = None
    while not over.is_set():
        code, j = call(f"/api/g/{room}/m?v={last or ''}&me=", kind="tv")
        if j.get("view"): check_view(j["view"], "TV", None); last = j["view"]["ver"]
        time.sleep(1.2)

# ---- the Table
body = {"pass": a.master} if a.master else {"app": True}
code, j = call("/api/games", body, kind="games")
room = j.get("room")
if not room: print("couldn't open a Table:", code, j); sys.exit(1)
names = NAMES[:a.players]
code, j = call(f"/api/g/{room}/m/create", {"name": names[0], "pass": "", **({"test": True, "bots": 8} if a.test else {})}, kind="create")
if not j.get("tok"): print("couldn't set up the Table:", code, j); sys.exit(1)
phones = [Phone(room, names[0], j["tok"])]
names = names[:a.players - len(j["view"]["players"]) + 1] # (a test game's bots have taken some seats)
if a.launch: subprocess.run(a.launch.format(room=room), shell=True)
print(f"room {room} · {'test game' if a.master else 'free app game'} · {a.players} phones" + (" · chaos" if a.chaos else ""), flush=True)

# everyone joins at once, plus some who shouldn't get in (a name already taken, one too many)
def join(n):
    code, j = call(f"/api/g/{room}/m/join", {"name": n}, kind="join")
    if j.get("tok"):
        with lock: phones.append(Phone(room, n, j["tok"]))
    return code, j
ts = [threading.Thread(target=join, args=(n,)) for n in names[1:]]
time.sleep(4 if a.launch else 0) # the TV's lobby, before everyone arrives
for x in ts: x.start()
for x in ts: x.join()
code, j = call(f"/api/g/{room}/m/join", {"name": names[1].upper()}, kind="join")
if j.get("tok"): note(f"a second phone joined as {names[1].upper()} (a name already taken)")
if a.players >= 24:
    code, j = call(f"/api/g/{room}/m/join", {"name": "TwentyFifth"}, kind="join")
    if j.get("tok"): note("a 25th phone got in")
print(f"{len(phones)} phones in", flush=True)
if len(phones) != len(names): note(f"only {len(phones)} of {len(names)} phones got in")
for p in phones: p.start()
threading.Thread(target=tv, args=(room,), daemon=True).start()

# ---- the night's trouble
done_chaos = set()
def chaos(v):
    rnd_ = v.get("round", 0); ph = v["phase"]
    host = next((p for p in phones if (p.v or {}).get("me", {}).get("director")), None)
    guests = [p for p in phones if p is not host and p.tok and not p.removed and (p.v or {}).get("me", {}).get("alive")]
    def once(k):
        if k in done_chaos: return False
        done_chaos.add(k); return True
    # a few phones in pockets, any time
    if R.random() < 0.02 and guests:
        p = R.choice(guests); p.quiet_until = time.time() + R.uniform(20, 90)
    if rnd_ >= 1 and ph == "day" and guests and once("lost"):
        p = R.choice(guests); print(f"{time.time() - t0:7.1f}s  ~ {p.name} loses their place (a new phone)", flush=True); p.lose_place()
    if rnd_ >= 2 and ph in ("trial", "talk") and host and once("hostdrop"):
        print(f"{time.time() - t0:7.1f}s  ~ the host's phone ({host.name}) dies", flush=True)
        host.quiet_until = time.time() + 40
        threading.Timer(41, host.lose_place).start()
    if rnd_ >= 3 and ph == "day" and host and guests and "hostdrop" in done_chaos and not host.lost and once("handover"):
        new = R.choice(guests); print(f"{time.time() - t0:7.1f}s  ~ {host.name} hands the host to {new.name}", flush=True)
        j = host.act({"a": "tool", "v": "host", "who": new.pid})
        if j.get("error"): note(f"hand-over refused: {j['error']}")
        else: host = new; guests = [p for p in guests if p is not new]
    if rnd_ >= 3 and ph == "day" and host and len(guests) > 9 and once("remove"):
        p = R.choice(guests); print(f"{time.time() - t0:7.1f}s  ~ the host takes {p.name} out (gone home)", flush=True)
        p.removed = True; j = host.act({"a": "tool", "v": "remove", "who": p.pid})
        if j.get("error"): note(f"taking {p.name} out was refused: {j['error']}")
    if ph == "vote" and rnd_ >= 2 and once("burst" + str(rnd_)):
        # everyone votes in the same instant
        vt = v.get("vote") or {}; voters = [p for p in phones if p.tok and (p.v or {}).get("me", {}).get("alive")]
        cands = [x for x in v["players"] if x["alive"] and x["id"] != vt.get("immune") and (not vt.get("revote") or x["id"] in vt["revote"])]
        go = threading.Barrier(len(voters) or 1)
        def ballot(p):
            c = [x for x in cands if x["id"] != p.pid]
            go.wait();
            if c: p.act({"a": "ballot", "v": R.choice(c)["id"]})
        bs = [threading.Thread(target=ballot, args=(p,)) for p in voters]
        for b in bs: b.start()
        for b in bs: b.join()
        print(f"{time.time() - t0:7.1f}s  ~ {len(voters)} phones voted at once", flush=True)

# ---- watch: the game moves on, and ends
seen, last_key, since, phases, shots = set(), None, time.time(), collections.Counter(), set()
while time.time() - t0 < a.limit:
    alive_phones = [p for p in phones if p.v and p.tok]
    if not alive_phones: time.sleep(1); continue
    v = max((p.v for p in alive_phones), key=lambda x: x["ver"])
    t = v.get("trial") or {}; it = t.get("item") or {}
    key = f"{v['phase']}·r{v['round']}·{t.get('key', '')}{t.get('stage', '')}{t.get('i', '')}{it.get('stage', '')}"
    if key != last_key:
        last_key, since = key, time.time(); phases[v["phase"]] += 1
        print(f"{time.time() - t0:7.1f}s  {key}  purse {v['pot']}  {sum(1 for p in v['players'] if p['alive'])} in", flush=True)
        # the TV at each new screen: each phase, and each Trial's stage (not every question)
        shot_key = f"{v['phase']}-{t.get('key', '')}-{t.get('stage', '')}-{v['round']}"
        if a.shot and shot_key not in shots:
            shots.add(shot_key); time.sleep(2.5)
            subprocess.run(a.shot.format(name=f"{len(shots):03d}-{v['phase']}" + (f"-{t.get('key')}-{t.get('stage')}" if t else "")), shell=True)
    elif time.time() - since > a.stall and not v.get("paused"):
        note(f"stuck on {key} for {int(time.time() - since)} s"); since = time.time()
    if a.chaos: chaos(v)
    if v["phase"] == "end":
        time.sleep(8)
        r = v.get("result") or {}
        print(f"the end: {r.get('winner')} win · {len(r.get('to') or [])} share the prize", flush=True)
        for p in phones: # a phone in a pocket at the end: out of the pocket, it should land on the end too
            if p.tok and not p.removed and not p.seen_end: p.quiet_until = 0; p.poll(); p.seen_end = (p.v or {}).get("phase") == "end"
        behind = [p.name for p in phones if p.tok and not p.removed and not p.seen_end]
        if behind: note(f"phones that never saw the end: {behind}")
        break
    time.sleep(1)
else:
    note(f"gave up after {a.limit} s at {last_key}")
over.set()

# ---- what happened
print("\n== requests")
for k, xs in sorted(lat.items()):
    xs = sorted(xs); print(f"  {k:10} {len(xs):6}  p50 {1000 * xs[len(xs) // 2]:6.0f} ms  p95 {1000 * xs[int(len(xs) * .95)]:6.0f} ms  max {1000 * xs[-1]:6.0f} ms")
print("== counts:", dict(sorted(stats.items())))
print("== phases:", dict(phases))
print(f"== {len(problems)} problems")
for t_, w in problems[:60]: print(f"  {t_:7.1f}s  {w}")
sys.exit(1 if problems else 0)
