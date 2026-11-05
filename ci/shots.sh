# The CI's ways of making a simulator and photographing the app in it (.github/workflows/ios.yml). Source it, with
# APP set to the app's bundle id.
#   make_device NAME WHAT              a new simulator (WHAT as ci/device.py takes it): its UDID
#   start UDID                         booting, in the background (while the app builds: a boot takes minutes here)
#   ready UDID                         booted, its status bar at 9:41, the app (Debug) installed
#   picture UDID DISPLAY FILE          the screen as it is (DISPLAY: 1 on the iPhone Duo's cover, empty elsewhere)
#   shot UDID DISPLAY FOLDER NAME WAIT ARGS…   the app launched with ARGS and photographed WAIT seconds later; if it's
#                                      still the launch screen's flat colour, again 12 seconds later (slow, or stuck?)
#   tour UDID DISPLAY FOLDER FILE:MOMENT…      the recorded moments one after another in one launch (-tour, Demo.swift),
#                                      each photographed once the app says it's drawn, then acknowledged by its number
#                                      (the app waits for that, so a slow picture can't leave it behind)
# FOLDER is under shots/ (empty for shots/ itself).

make_device() {
  local out t r
  while read -r t r; do
    out=$(xcrun simctl create "$1" "$t" "$r" 2>&1) && { echo "the $1: $t on $r" >&2; echo "$out"; return 0; }
    echo "not $t on $r: $out" >&2
  done < <(python3 ci/device.py "$2")
  return 1
}

start() {
  xcrun simctl boot "$1"
}

ready() {
  xcrun simctl bootstatus "$1" -b > /dev/null
  xcrun simctl status_bar "$1" override --time 9:41 --batteryState charged --batteryLevel 100 || true
  xcrun simctl install "$1" build/Build/Products/Debug-iphonesimulator/TheBetrayal.app
}

picture() {
  if [ -n "$2" ]; then xcrun simctl io "$1" screenshot --display="$2" "$3" > /dev/null 2>&1 || echo "no picture: $3"
  else xcrun simctl io "$1" screenshot "$3" > /dev/null 2>&1 || echo "no picture: $3"; fi
}

shot() {
  local dev=$1 disp=$2 dir=$3 name=$4 wait=$5; shift 5
  local f="shots/${dir:+$dir/}$name.png"
  xcrun simctl terminate "$dev" "$APP" 2>/dev/null || true
  xcrun simctl launch "$dev" "$APP" -noatt "$@" > /dev/null || { echo "::warning::couldn't open the app for $name"; return 0; }
  sleep "$wait"
  picture "$dev" "$disp" "$f"
  if [ -f "$f" ] && [ "$(stat -f%z "$f")" -lt 400000 ]; then
    sleep 12; picture "$dev" "$disp" "$f"
    if [ "$(stat -f%z "$f")" -lt 400000 ]; then echo "::warning::$name: still blank after $((wait + 12)) seconds"; else echo "$name: slow (drawn by $((wait + 12)) seconds)"; fi
  fi
}

tour() {
  local dev=$1 disp=$2 dir=$3; shift 3
  local list="" p n=0 k f data
  for p in "$@"; do list="$list${list:+,}${p#*:}"; done
  xcrun simctl terminate "$dev" "$APP" 2>/dev/null || true
  xcrun simctl launch "$dev" "$APP" -noatt -tour "$list" > /dev/null || { echo "::warning::couldn't start the tour"; return 0; }
  data=$(xcrun simctl get_app_container "$dev" "$APP" data)
  for p in "$@"; do
    f="shots/${dir:+$dir/}${p%%:*}.png"
    for k in $(seq 1 300); do grep -q "^$n " "$data/Documents/tour/ready" 2>/dev/null && break; sleep 0.2; done
    grep -q "^$n " "$data/Documents/tour/ready" 2>/dev/null || echo "::warning::${p#*:}: not drawn in 60 seconds"
    picture "$dev" "$disp" "$f"
    echo "$n" > "$data/Documents/tour/next"
    n=$((n + 1))
  done
}
