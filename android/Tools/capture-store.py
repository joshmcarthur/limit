#!/usr/bin/env python3
"""Retake Play Store stills and a live review screenrecord on the attached emulator.

Usage, from android/:
  python3 Tools/capture-store.py
  python3 Tools/capture-store.py --horokiwi

The register generation is the name in ../data/register-check/current.

Needs adb, an API 36 emulator, ffmpeg, the debug APK installed, and
../data/register-check. Records with the emulator console at 30 fps (not
adb shell screenrecord, which drops still frames). scrcpy is the fallback.
"""
from __future__ import annotations

import os
import re
import signal
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANDROID = ROOT / "android"
OUT = ANDROID / "AppStore" / "screenshots"
VIDEO = ANDROID / "AppStore" / "review-video"
PKG = "com.joshmcarthur.limit"
REGISTER = ROOT / "data" / "register-check"
ADB = os.environ.get("ADB", "adb")

# lat, lon — same stretches as iOS/Tools/store-screenshots.sh
CENTRAL = [(-41.2880, 174.7772), (-41.2930, 174.7775), (-41.2990, 174.7780), (-41.3050, 174.7785)]
DESERT = [(-39.2941, 175.7408), (-39.2921, 175.7408), (-39.2901, 175.7408), (-39.2881, 175.7408)]
PORIRUA = [(-41.0795, 174.8667), (-41.0800, 174.8662), (-41.0805, 174.8657)]
OPEN_ROAD = [(-41.0767, 174.8709), (-41.0762, 174.8714)]
CUPERTINO = [(37.3349, -122.0090), (37.3354, -122.0085)]
# Both points stay inside the zone (checked 2 November 2026). The sign lists several speeds,
# so the circle is empty and red. Do not keep a shot that shows 100.
HOROKIWI = [(-41.24460, 174.81851), (-41.24249, 174.82106)]

PORTRAIT_FAB = (855, 2237)
SETTINGS = (996, 168)
BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


def run(args: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(args, check=False, **kwargs)


def adb(*args: str, timeout: float | None = 30) -> subprocess.CompletedProcess:
    return run([ADB, *args], timeout=timeout, capture_output=True, text=True)


def emu(*args: str) -> str:
    result = run([ADB, "emu", *args], timeout=15, capture_output=True, text=True)
    out = (result.stdout or "") + (result.stderr or "")
    if result.returncode != 0 or "KO:" in out:
        print(f"  emu {' '.join(args)} -> {out.strip()[:200]}")
    return out


def sh(cmd: str) -> subprocess.CompletedProcess:
    return adb("shell", cmd)


def tap(x: int, y: int) -> None:
    sh(f"input tap {x} {y}")
    time.sleep(0.4)


def demo_mode() -> None:
    sh("settings put global sysui_demo_allowed 1")
    sh("am broadcast -a com.android.systemui.demo -e command enter")
    sh("am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941")
    sh(
        "am broadcast -a com.android.systemui.demo -e command network "
        "-e mobile show -e level 4 -e datatype 3g -e wifi show -e fully true"
    )
    sh("am broadcast -a com.android.systemui.demo -e command battery -e plugged true -e level 100")
    sh("am broadcast -a com.android.systemui.demo -e command notifications -e visible false")


def disable_circle_to_search() -> None:
    # Long-press home/nav stole the last live take.
    sh("settings put secure assistant ''")
    sh("settings put secure voice_interaction_service ''")
    sh("settings put secure search_all_entrypoints_enabled 0")
    sh("settings put secure selected_search_engine 0")


def night(on: bool) -> None:
    sh(f"cmd uimode night {'yes' if on else 'no'}")
    time.sleep(1.2)


def landscape(on: bool) -> None:
    sh("settings put system accelerometer_rotation 0")
    sh(f"settings put system user_rotation {1 if on else 0}")
    time.sleep(2)


def grant() -> None:
    for perm in (
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.POST_NOTIFICATIONS",
    ):
        adb("shell", "pm", "grant", PKG, perm)


def register_generation() -> str:
    current = REGISTER / "current"
    name = current.read_text().strip()
    if not name:
        raise SystemExit(f"empty {current}")
    return name


def push_register() -> None:
    gen = register_generation()
    gen_dir = REGISTER / gen
    dest = f"files/Register/{gen}"
    sh(f"run-as {PKG} mkdir -p {dest}")

    def send(local: Path, remote: str) -> None:
        # adb shell stdin is not binary-safe. Push to the sdcard, then copy on the device.
        print(f"  push {local.name} ({local.stat().st_size} bytes)")
        tmp = f"/sdcard/limit-{local.name}"
        result = adb("push", str(local), tmp, timeout=180)
        if result.returncode != 0:
            raise RuntimeError(f"adb push failed: {local.name}: {result.stderr}")
        copied = adb("shell", f"cat {tmp} | run-as {PKG} sh -c 'cat > {remote}'", timeout=180)
        if copied.returncode != 0:
            raise RuntimeError(f"copy failed: {remote}: {copied.stderr}")
        sized = sh(f"run-as {PKG} wc -c {remote}")
        written = int((sized.stdout or "0").split()[0])
        if written != local.stat().st_size:
            raise RuntimeError(f"{local.name}: device has {written} bytes, host has {local.stat().st_size}")
        adb("shell", "rm", "-f", tmp)

    send(gen_dir / "register.json", f"{dest}/register.json")
    send(gen_dir / "register.lmtz", f"{dest}/register.lmtz")
    send(REGISTER / "current", "files/Register/current")


def set_onboarded() -> None:
    settings = (
        '{"showOnLockScreen":true,"overTolerance":3,'
        '"hasCompletedOnboarding":true,"suggestEndingDrive":true}'
    )
    xml = (
        "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n"
        "<map>\n"
        f"    <string name=\"settings.v1\">{settings}</string>\n"
        "    <boolean name=\"location.prompted\" value=\"true\" />\n"
        "    <boolean name=\"notifications.prompted\" value=\"true\" />\n"
        "</map>\n"
    )
    sh(f"run-as {PKG} mkdir -p shared_prefs")
    result = run(
        [ADB, "shell", f"run-as {PKG} sh -c 'cat > shared_prefs/limit.xml'"],
        input=xml.encode(),
        timeout=30,
    )
    if result.returncode != 0:
        raise RuntimeError("failed to write prefs")


def launch() -> None:
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.5)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(3)


def driving() -> bool:
    out = adb("shell", "dumpsys", "activity", "services", PKG).stdout
    return "DriveForegroundService" in out and "isForeground=true" in out


def dump_root() -> ET.Element | None:
    try:
        adb("shell", "uiautomator", "dump", "--compressed", "/sdcard/window_dump.xml", timeout=20)
    except subprocess.TimeoutExpired:
        print("  ui dump timed out")
        return None
    pull = adb("exec-out", "cat", "/sdcard/window_dump.xml")
    try:
        return ET.fromstring(pull.stdout)
    except ET.ParseError:
        return None


def dump_texts() -> list[str]:
    root = dump_root()
    if root is None:
        return []
    texts: list[str] = []
    for node in root.iter("node"):
        text = node.attrib.get("text") or ""
        desc = node.attrib.get("content-desc") or ""
        if text:
            texts.append(text)
        if desc:
            texts.append(desc)
    return texts


def tap_label(label: str) -> bool:
    root = dump_root()
    if root is None:
        return False
    for node in root.iter("node"):
        if node.attrib.get("text") != label and node.attrib.get("content-desc") != label:
            continue
        match = BOUNDS.search(node.attrib.get("bounds") or "")
        if not match:
            continue
        x1, y1, x2, y2 = (int(g) for g in match.groups())
        tap((x1 + x2) // 2, (y1 + y2) // 2)
        return True
    return False


def start_drive() -> None:
    if driving():
        return
    if not tap_label("Start drive"):
        tap(*PORTRAIT_FAB)
    time.sleep(1.5)
    if not driving() and not tap_label("Start drive"):
        tap(840, 2140)
        time.sleep(1.5)


def end_drive() -> None:
    if not driving():
        return
    landscape(False)
    if not tap_label("End drive"):
        tap(*PORTRAIT_FAB)
    time.sleep(1.2)


def kmh_to_knots(kmh: float) -> float:
    return kmh / 1.852


def geo_drive(points: list[tuple[float, float]], kmh: float, seconds: float) -> None:
    knots = kmh_to_knots(kmh)
    step = 0.4
    n = max(2, int(seconds / step))
    for i in range(n):
        t = i / (n - 1)
        seg = t * (len(points) - 1)
        a = int(seg)
        b = min(a + 1, len(points) - 1)
        frac = seg - a
        lat = points[a][0] + (points[b][0] - points[a][0]) * frac
        lon = points[a][1] + (points[b][1] - points[a][1]) * frac
        emu("geo", "fix", f"{lon:.6f}", f"{lat:.6f}", "20", "12", f"{knots:.2f}")
        time.sleep(step)


def shot(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/limit-shot.png"
    cap = adb("shell", "screencap", "-p", remote, timeout=30)
    if cap.returncode != 0:
        raise RuntimeError(f"screencap failed for {path.name}: {cap.stderr}")
    pull = adb("pull", remote, str(path), timeout=30)
    if pull.returncode != 0 or not path.exists() or path.stat().st_size < 1000:
        raise RuntimeError(f"pull failed for {path.name}: {pull.stderr}")
    print(f"  saved {path.relative_to(ROOT)}")


def ffmpeg_mp4(src: Path, dest: Path, extra_vf: str | None = None) -> bool:
    vf = "fps=30,format=yuv420p"
    if extra_vf:
        vf = f"{vf},{extra_vf}"
    result = run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(src),
            "-vf",
            vf,
            "-c:v",
            "libx264",
            "-crf",
            "20",
            "-movflags",
            "+faststart",
            str(dest),
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("  ffmpeg failed:", (result.stderr or "")[-400:])
        return False
    return True


class Recorder:
    def __init__(self, dest: Path) -> None:
        self.dest = dest
        self.webm = dest.with_suffix(".webm")
        self.proc: subprocess.Popen | None = None
        self.mode = "emu"

    def start(self) -> None:
        self.dest.parent.mkdir(parents=True, exist_ok=True)
        for path in (self.dest, self.webm):
            if path.exists():
                path.unlink()
        emu("screenrecord", "stop")
        reply = emu("screenrecord", "start", "--fps", "30", "--bit-rate", "8M", str(self.webm))
        time.sleep(0.4)
        if "KO:" not in reply:
            print(f"  recording (emulator 30 fps) {self.webm.name}")
            return
        self.mode = "scrcpy"
        self.proc = subprocess.Popen(
            [
                "scrcpy",
                "--no-window",
                "-N",
                "--no-audio",
                "--max-fps=30",
                "-r",
                str(self.dest),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(1.2)
        print(f"  recording (scrcpy) {self.dest.name}")

    def stop(self) -> Path:
        if self.mode == "emu":
            emu("screenrecord", "stop")
            time.sleep(1.2)
            src = self.webm if self.webm.exists() else self.dest
        else:
            if self.proc and self.proc.poll() is None:
                self.proc.send_signal(signal.SIGINT)
                try:
                    self.proc.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    self.proc.kill()
            src = self.dest
        raw = VIDEO / "raw.mp4"
        if src.suffix != ".mp4":
            ffmpeg_mp4(src, raw)
        elif src != raw:
            src.replace(raw)
        print(f"  raw {raw.relative_to(ROOT)} ({raw.stat().st_size if raw.exists() else 0} bytes)")
        return raw


def wait_for_drive_ui(seconds: float = 12) -> None:
    deadline = time.time() + seconds
    while time.time() < deadline:
        texts = dump_texts()
        if "Start drive" in texts or "End drive" in texts or "GPS · good" in texts:
            return
        time.sleep(0.8)
    print("  drive UI not confirmed; continuing")


def stills() -> None:
    print("Stills")
    night(False)
    landscape(False)

    print("06 Setup")
    adb("shell", "am", "force-stop", PKG)
    sh("cmd connectivity airplane-mode enable")
    time.sleep(1)
    adb("shell", "pm", "clear", PKG)
    launch()
    time.sleep(0.8)
    shot(OUT / "06-welcome.png")
    sh("cmd connectivity airplane-mode disable")
    time.sleep(1)

    print("Fill register")
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.5)
    push_register()
    set_onboarded()
    grant()
    launch()
    wait_for_drive_ui()
    start_drive()

    print("01 Drive light")
    geo_drive(CENTRAL, 28, 8)
    shot(OUT / "01-drive-light.png")

    print("02 Over the limit")
    geo_drive(DESERT, 104, 8)
    shot(OUT / "02-over-the-limit-104-in-100.png")

    print("03 Drive dark")
    night(True)
    geo_drive(CENTRAL, 26, 8)
    shot(OUT / "03-drive-dark.png")

    print("04 Landscape dark")
    landscape(True)
    time.sleep(1)
    geo_drive(CENTRAL, 27, 8)
    shot(OUT / "04-landscape-dark.png")
    landscape(False)
    night(False)

    print("05 Notification")
    geo_drive(DESERT, 96, 6)
    sh("cmd statusbar expand-notifications")
    time.sleep(1.5)
    shot(OUT / "05-lock-screen.png")
    shot(OUT / "05-notification-shade.png")
    sh("cmd statusbar collapse")
    time.sleep(0.6)

    horokiwi_still(prepare=False)


def write_srt(scenes: list[tuple[float, str]], path: Path) -> None:
    def ts(seconds: float) -> str:
        ms = max(0, int(seconds * 1000))
        hours, ms = divmod(ms, 3_600_000)
        minutes, ms = divmod(ms, 60_000)
        secs, ms = divmod(ms, 1000)
        return f"{hours:02}:{minutes:02}:{secs:02},{ms:03}"

    lines = ["1\n00:00:00,000 --> 00:00:03,000\nLimit · simulated GPS on the Android emulator\n"]
    for i, (start, label) in enumerate(scenes):
        end = scenes[i + 1][0] if i + 1 < len(scenes) else start + 3
        lines.append(f"{i + 2}\n{ts(start)} --> {ts(end)}\n{label}\n")
    path.write_text("\n".join(lines))


def live_record() -> None:
    print("Live record")
    night(False)
    landscape(False)
    launch()
    wait_for_drive_ui()
    start_drive()
    rec = Recorder(VIDEO / "raw.mp4")
    rec.start()
    t0 = time.time()
    scenes: list[tuple[float, str]] = []

    def mark(label: str) -> None:
        scenes.append((time.time() - t0, label))
        print(f"  {label}")

    mark("Wellington Central, 30 km/h zone")
    geo_drive(CENTRAL, 28, 6)
    mark("Porirua City, 50 km/h zone")
    geo_drive(PORIRUA, 47, 6)
    mark("Desert Road SH 1, 100 km/h zone")
    geo_drive(DESERT, 96, 6)
    mark("Over the limit: 104 in a 100")
    geo_drive(DESERT, 104, 6)
    mark("Ongoing drive notification")
    sh("cmd statusbar expand-notifications")
    geo_drive(DESERT, 96, 4)
    sh("cmd statusbar collapse")
    time.sleep(0.5)
    mark("Settings")
    if not tap_label("Settings"):
        tap(*SETTINGS)
    time.sleep(4)
    sh("input keyevent KEYCODE_BACK")
    time.sleep(0.8)
    mark("Outside New Zealand")
    geo_drive(CUPERTINO, 40, 5)
    mark("Open road")
    geo_drive(OPEN_ROAD, 80, 5)
    mark("End drive")
    end_drive()
    time.sleep(3)
    raw = rec.stop()
    srt = VIDEO / "review.srt"
    write_srt(scenes, srt)
    final = VIDEO / "limit-review-demo.mp4"
    style = "Fontsize=18,Alignment=2,MarginV=40,Outline=1"
    burned = ffmpeg_mp4(raw, final, extra_vf=f"subtitles={srt}:force_style='{style}'")
    if not burned:
        ffmpeg_mp4(raw, final)
    print(f"  wrote {final.relative_to(ROOT)}")


def horokiwi_still(prepare: bool = True) -> None:
    """Empty red circle on Horokiwi. Slow, so the route stays inside the thin polygon."""
    print("07 Horokiwi variable")
    night(False)
    landscape(False)
    if prepare:
        adb("shell", "am", "force-stop", PKG)
        time.sleep(0.5)
        push_register()
        set_onboarded()
        grant()
        launch()
        wait_for_drive_ui()
        start_drive()
    sh("cmd statusbar collapse")
    time.sleep(0.6)
    deadline = time.time() + 180
    texts: list[str] = []
    while time.time() < deadline:
        geo_drive(HOROKIWI, 15, 4)
        texts = dump_texts()
        print("  screen:", " | ".join(texts[:12]))
        if any("Horokiwi" in text or "Variable limit, obey" in text for text in texts):
            break
        time.sleep(3)
    else:
        raise SystemExit("Horokiwi did not show an empty circle")
    shot(OUT / "07-drive-variable.png")
    sh("cmd statusbar expand-notifications")
    time.sleep(1.5)
    shade = dump_texts()
    print("  shade:", " | ".join(shade[:16]))
    if any("Variable" in text or "Horokiwi" in text for text in shade):
        shot(OUT / "07-notification-variable.png")
    else:
        print("  shade does not show the variable sign; leaving it")
    sh("cmd statusbar collapse")
    time.sleep(0.6)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    VIDEO.mkdir(parents=True, exist_ok=True)
    devices = adb("devices").stdout
    if "device" not in devices.split("List of devices attached", 1)[-1]:
        raise SystemExit("no emulator attached")
    gen = register_generation()
    if not (REGISTER / gen / "register.lmtz").exists():
        raise SystemExit(f"missing register at {REGISTER / gen}")
    disable_circle_to_search()
    demo_mode()
    if "--horokiwi" in sys.argv:
        horokiwi_still()
        print("Done.")
        return
    stills()
    live_record()
    print("Done.")


if __name__ == "__main__":
    main()
