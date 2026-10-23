#!/usr/bin/env bash
# Captures the three drive screens that the App Store header / search results image is made from.
#
#   Tools/creative-asset-capture.sh
#
# Same method as Tools/store-screenshots.sh: build the app, install it on a clean simulator, fill it with a
# copy of the real speed limit register, drive a simulated trip with `xcrun simctl location`, and save the
# screen. The shots go to AppStore/creative-assets/raw; Tools/frame-creative-asset.py turns them into the image.
#
# Environment:
#   DEVICE   simulator UDID or name. Default: the newest "iPhone 17 Pro Max" (the 6.9-inch size).
#   OUT      output folder. Default: AppStore/creative-assets/raw
#   REFRESH  set to 1 to download the register again (it is kept in data/register-check, which is not committed).
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE=com.joshmcarthur.Limit
OUT=${OUT:-AppStore/creative-assets/raw}
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
portrait() {
  xcodegen generate --spec Tools/screenshots/rotate/project.yml --project "$WORK" >/dev/null
  (cd "$WORK" && TEST_RUNNER_TARGET_ORIENTATION=portrait xcodebuild -project Rotate.xcodeproj -scheme RotateUITests \
    -destination "id=$UDID" -derivedDataPath "$WORK/rotate-dd" test CODE_SIGNING_ALLOWED=NO -quiet >/dev/null)
}

# Routes (latitude,longitude), each a short stretch that stays in one zone. Check the road name, sign and
# speed in every shot: if the register changes, a route can land in a different zone.
CENTRAL=("-41.2880,174.7772" "-41.2930,174.7775" "-41.2990,174.7780" "-41.3050,174.7785")   # 30, Wellington Central
PORIRUA=("-41.0795,174.8667" "-41.0793,174.8672" "-41.0791,174.8677" "-41.0789,174.8682")   # 50, Porirua City
DESERT=("-39.2941,175.7408" "-39.2921,175.7408" "-39.2901,175.7408" "-39.2881,175.7408")    # 100, Turangi To Waiouru, SH 1

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
portrait
xcrun simctl ui "$UDID" appearance light
xcrun simctl location "$UDID" clear

# --- Fill the app: a clean install, onboarding done, the register in place --------------------------
xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" $BUNDLE >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant location $BUNDLE
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

# --- The three shots: every speed under its limit ---------------------------------------------------
echo "30, Wellington Central, 28 km/h"
launch; route 7.8 "${CENTRAL[@]}"; sleep 10
shot "$OUT/01-wellington-30.png"

echo "50, Porirua City, 47 km/h"
launch; route 13.1 "${PORIRUA[@]}"; sleep 10
shot "$OUT/02-porirua-50.png"

echo "100, Turangi To Waiouru SH 1, 96 km/h"
launch; route 26.7 "${DESERT[@]}"; sleep 10
shot "$OUT/03-desert-road-100.png"

xcrun simctl location "$UDID" clear
xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
echo "Done. Check the road name, sign and speed in each shot, then run Tools/frame-creative-asset.py"
