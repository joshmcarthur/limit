#!/usr/bin/env bash
# Retakes the App Store screenshots (6.9-inch) in the iOS Simulator.
#
#   Tools/store-screenshots.sh
#
# It builds the app, installs it on a simulator, fills it with a copy of the real speed limit register, and
# drives simulated trips with `xcrun simctl location`, saving into AppStore/screenshots/6.9-inch.
# See AppStore/README.md for what each shot is meant to show and the rules for them.
#
# Environment:
#   DEVICE   simulator UDID or name. Default: the newest "iPhone 17 Pro Max" (the 6.9-inch size).
#   OUT      output folder. Default: AppStore/screenshots/6.9-inch
#   REFRESH  set to 1 to download the register again (it is kept in data/register-check, which is not committed).
#
# Not scripted: the Lock Screen shot (05). It needs the phone locked and woken, which `simctl` can't do.
# The script finishes by starting a trip and printing how to take it.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE=com.joshmcarthur.Limit
OUT=${OUT:-AppStore/screenshots/6.9-inch}
WORK=$(mktemp -d)
mkdir -p "$OUT"

# --- Which simulator ---------------------------------------------------------------------------------
if [ -z "${DEVICE:-}" ]; then DEVICE="iPhone 17 Pro Max"; fi
UDID=$(python3 - "$DEVICE" <<'PY'
import json, subprocess, sys
want = sys.argv[1]
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))["devices"]
def version(runtime): return [int(p) for p in runtime.rsplit("iOS-", 1)[-1].split("-")] if "iOS-" in runtime else []
matches = [(version(r), d["udid"]) for r, ds in data.items() if "iOS" in r for d in ds if d["name"] == want or d["udid"] == want]
if not matches: sys.exit("no simulator called " + want)
print(max(matches)[1])
PY
)
echo "Simulator: $DEVICE ($UDID)"

# --- Build -------------------------------------------------------------------------------------------
xcodegen generate >/dev/null
xcodebuild -project Limit.xcodeproj -scheme Limit -destination "id=$UDID" -derivedDataPath "$WORK/dd" \
  CODE_SIGNING_ALLOWED=NO -quiet build
APP="$WORK/dd/Build/Products/Debug-iphonesimulator/Limit.app"

# --- The register to drive with ----------------------------------------------------------------------
if [ "${REFRESH:-0}" = 1 ]; then rm -rf data/register-check; fi
if [ ! -d data/register-check ]; then
  echo "Downloading the register (about a minute)..."
  swift run -c release RegisterCheck data/register-check >/dev/null
fi

# --- Simulator helpers -------------------------------------------------------------------------------
shot() { timeout 20 xcrun simctl io "$UDID" screenshot "$1" >/dev/null 2>&1; echo "  saved $1"; }
route() { local speed=$1; shift; printf '%s\n' "$@" | xcrun simctl location "$UDID" start --speed="$speed" - >/dev/null 2>&1; }
launch() { xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true; xcrun simctl launch "$UDID" $BUNDLE >/dev/null; sleep 3; }
rotate() {
  xcodegen generate --spec Tools/screenshots/rotate/project.yml --project "$WORK" >/dev/null
  (cd "$WORK" && TEST_RUNNER_TARGET_ORIENTATION=$1 xcodebuild -project Rotate.xcodeproj -scheme RotateUITests \
    -destination "id=$UDID" -derivedDataPath "$WORK/rotate-dd" test CODE_SIGNING_ALLOWED=NO -quiet >/dev/null)
}

# Routes (latitude,longitude). Wellington Central is a 30 zone. The Desert Road (SH 1, Turangi to Waiouru)
# is a 100 zone with a clear road name. Both were found by searching the downloaded register for a straight
# stretch that stays in one zone; if the layer changes, check the road name and limit in each shot.
CENTRAL=("-41.2880,174.7772" "-41.2930,174.7775" "-41.2990,174.7780" "-41.3050,174.7785")
DESERT=("-39.2941,175.7408" "-39.2921,175.7408" "-39.2901,175.7408" "-39.2881,175.7408")

# 9:41, full signal, charging.
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
rotate portrait
xcrun simctl ui "$UDID" appearance light
xcrun simctl location "$UDID" clear

# --- 06 The first screen, from a clean install ------------------------------------------------------
echo "Welcome screen"
xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" $BUNDLE >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant location $BUNDLE
launch
shot "$OUT/06-welcome.png"
xcrun simctl terminate "$UDID" $BUNDLE

# --- Fill the app: onboarding done, and the register in place ---------------------------------------
CONTAINER=$(xcrun simctl get_app_container "$UDID" $BUNDLE data)
REGISTER="$CONTAINER/Library/Application Support/Register"
rm -rf "$REGISTER"; mkdir -p "$REGISTER" "$CONTAINER/Library/Preferences"
cp -R data/register-check/. "$REGISTER/"
python3 - "$REGISTER" "$CONTAINER/Library/Preferences/$BUNDLE.plist" <<'PY'
import datetime, glob, json, plistlib, sys
register, plist = sys.argv[1], sys.argv[2]
# "Checked just now", so the app doesn't go and fetch a newer register mid-shot.
for f in glob.glob(register + "/gen-*/register.json"):
    meta = json.load(open(f))
    meta["checkedAt"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    json.dump(meta, open(f, "w"))
# Onboarding done, everything else at its default. All three keys are needed or the app falls back to defaults.
settings = json.dumps({"showOnLockScreen": True, "overTolerance": 3, "hasCompletedOnboarding": True}).encode()
plistlib.dump({"settings.v1": settings}, open(plist, "wb"))
PY

# --- 01 Driving, light: 28 in a 30 ------------------------------------------------------------------
echo "Drive, light"
xcrun simctl ui "$UDID" appearance light
launch; route 7.8 "${CENTRAL[@]}"; sleep 10
shot "$OUT/01-drive-light.png"

# --- 02 A realistic over-the-limit case: 104 in a 100 -----------------------------------------------
echo "Over the limit"
launch; route 28.9 "${DESERT[@]}"; sleep 7
shot "$OUT/02-over-the-limit-104-in-100.png"

# --- 03 Driving, dark: 26 in a 30 -------------------------------------------------------------------
echo "Drive, dark"
xcrun simctl ui "$UDID" appearance dark
launch; route 7.2 "${CENTRAL[@]}"; sleep 10
shot "$OUT/03-drive-dark.png"

# --- 04 Landscape, dark: 27 in a 30 -----------------------------------------------------------------
echo "Landscape"
rotate landscape
launch; route 7.5 "${CENTRAL[@]}"; sleep 10
shot "$WORK/landscape.png"
# simctl saves in the device's own orientation, so turn it upright.
sips -r 270 "$WORK/landscape.png" --out "$OUT/04-landscape-dark.png" >/dev/null
echo "  saved $OUT/04-landscape-dark.png"
rotate portrait
xcrun simctl ui "$UDID" appearance light

# --- 05 The Lock Screen: set it up, then take it by hand --------------------------------------------
launch; route 26.7 "${DESERT[@]}"
cat <<EOF

Lock Screen (05) is by hand:
  1. In the Simulator press Cmd+L to lock, and wait about ten seconds.
  2. Wake it (press the home button, Device > Home), allow Live Activities if asked.
  3. Take it:  xcrun simctl io "$UDID" screenshot "$OUT/05-lock-screen.png"
The trip lasts a couple of minutes. Rerun the last step of the script (or this whole script) for another go.

Check each shot before keeping it: speeds at or under the limit apart from 02, real road names, nothing
stale or "Searching for GPS". Done: $OUT
EOF
