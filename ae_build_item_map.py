#!/usr/bin/env python3
"""Pull the Another Eden item map off the device and write a sorted, categorized copy.

Run it from anywhere -- it does everything in one shot:
  1. `adb kill-server`, then `adb connect 127.0.0.1:5555` -- the emulator's ADB port.
  2. `adb root` and pull the module's dump:
        /data/data/games.wfs.anothereden/files/ae_item_map.txt
     This is the file the "Dump item map" button in the overlay writes, so tap it in-game
     once first. The dumper reuses the game's own name resolver, so it always auto-updates.
  3. Parse the `EnglishName::itemId` lines, bucket them by item-id category, sort, and write
     two files NEXT TO THIS SCRIPT:
        ae_item_map.txt          raw pull, exactly as the device wrote it
        ae_item_map.sorted.txt   sorted + categorized (the deliverable)
  4. Print a category table so you can see every bucket and its count.

If 7huibjgkll.txt (your hand-maintained list) sits next to this script it is used only to
carry forward WARNING_/DANGER_ annotations and to report renames -- it is never required.

No RVAs, no patching here: this only reads a file the in-process dumper already produced.
"""
from __future__ import annotations

import argparse
import base64
import re
import shutil
import subprocess
import sys
from collections import OrderedDict, defaultdict
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PACKAGE = "games.wfs.anothereden"
PORTS = ("127.0.0.1:5555",)  # the emulator's ADB port
RAW_OUT = "ae_item_map.txt"
SORTED_OUT = "ae_item_map.sorted.txt"
HAND_FILE = "7huibjgkll.txt"

# itemId prefix -> human category. 9-digit ids bucket on their first 3 digits, 10-digit ids on
# their first 4. This order is cosmetic; output is always sorted by the numeric prefix.
CATEGORY_NAMES = {
    "177": "Tickets & Prayer Pieces",
    "205": "Currencies & Medals",
    "209": "Drills & Atmo Equipment",
    "211": "Weapons",
    "217": "Accessories",
    "218": "Charms",
    "221": "Crafting Parts (Lenses/Devices)",
    "222": "Stat Fragments & Crystals",
    "231": "Cat Food",
    "232": "Cat Toys",
    "235": "Random Class Tickets",
    "241": "Crafting & Drop Materials",
    "242": "Class Records",
    "243": "Promised Fruit (ACCOUNT-CORRUPTION RISK)",
    "245": "Guiding Light / Luring Shadow",
    "246": "Scrolls",
    "247": "Soil & Water (Refining)",
    "275": "Skill Badges (Magic)",
    "279": "Alchemical Materials (ACCOUNT-CORRUPTION RISK)",
    "281": "Stat Badges",
    "288": "Proofs / Power-of-X",
    "295": "Treasures & Collectibles",
    "297": "Light/Shadow Upgrade Items",
    "298": "Spells",
    "450": "Cat Materials",
    "452": "Hats & Headgear",
    "464": "Battle Decks",
    "492": "Key Items (Story/Prisma)",
    "564": "Keys",
    "565": "Mission Items & Misc",
    "764": "Communications & Livestream Logs",
    "773": "Fish",
    "774": "Proof of Harpoon Power",
    "775": "Harpoons",
    "776": "Harpoon Tips",
    "777": "Fishing Traps",
    "778": "Cooling Boxes",
    "791": "OOPArts",
    "870": "Fish",
    "873": "Bait",
    "874": "Fishing Rods",
    "875": "Reels",
    "876": "Fish Hooks",
    "877": "Floats",
    "878": "Cooling Boxes (Wooden)",
    "900": "Mining Hammers",
    "961": "Cooking Ingredients",
    "2008": "Weapons (Fists)",
    "2061": "Talegems (Badge Effects)",
    "2075": "Records",
    "2076": "Asterorbs",
    "2078": "Gathering Materials",
    "2080": "Gathering Tools",
    "2126": "Fishing Spots",
    "2132": "Weapons (Scythes)",
    "2136": "Refining Materials",
    "2138": "Cooked Dishes",
    "2142": "Equipment Replicas",
}
DANGER_PREFIXES = {"243", "279"}
NOTE_RE = re.compile(
    r"^((?:[A-Z][A-Z0-9]*_)*(?:WARNING|DANGER|DO_NOT|ACCOUNT|CORRUPTION)[A-Z0-9_]*)_(.+)$"
)


# ---- adb plumbing --------------------------------------------------------------------------

def find_adb() -> str:
    adb_bin = shutil.which("adb")
    if adb_bin:
        return adb_bin
    fallback = Path.home() / "Library/Android/sdk/platform-tools/adb"
    if fallback.exists():
        return str(fallback)
    sys.exit("adb not found on PATH or at ~/Library/Android/sdk/platform-tools/adb")


def adb(adb_bin, *args, serial=None, text=True):
    cmd = [adb_bin] + (["-s", serial] if serial else []) + list(args)
    return subprocess.run(cmd, capture_output=True, text=text)


def connect(adb_bin) -> str:
    """kill-server, then connect to the first reachable emulator port; return its serial."""
    adb(adb_bin, "kill-server")
    adb(adb_bin, "start-server")
    for serial in PORTS:
        out = adb(adb_bin, "connect", serial)
        msg = ((out.stdout or "") + (out.stderr or "")).strip()
        if "connected to" in msg:  # matches "connected to" and "already connected to"
            print(f"adb: {msg}")
            return serial
    # fall back to any already-attached device
    out = adb(adb_bin, "devices")
    for line in (out.stdout or "").splitlines()[1:]:
        if "\tdevice" in line:
            serial = line.split("\t", 1)[0]
            print(f"adb: using attached device {serial}")
            return serial
    sys.exit("Could not connect to 127.0.0.1:5555 or any device. Is the emulator running?")


def pull_dump(adb_bin, serial, device_file, dest: Path) -> None:
    adb(adb_bin, "root", serial=serial)            # /data/data needs root; no-op if already root
    adb(adb_bin, "wait-for-device", serial=serial)
    out = adb(adb_bin, "pull", device_file, str(dest), serial=serial)
    if out.returncode == 0 and dest.exists() and dest.stat().st_size > 0:
        print(f"pulled {device_file} -> {dest.name} ({dest.stat().st_size} bytes)")
        return
    # fallback: su + base64 (binary-safe) for non-rootable adb
    res = adb(adb_bin, "exec-out", f"su -c 'base64 {device_file}'", serial=serial, text=False)
    if res.returncode == 0 and res.stdout:
        dest.write_bytes(base64.b64decode(res.stdout))
        print(f"pulled via su -> {dest.name} ({dest.stat().st_size} bytes)")
        return
    sys.exit(f"Failed to pull {device_file}. Tap 'Dump item map' in the overlay first, and make "
             f"sure the emulator is rooted.\n{(out.stderr or '').strip()}")


# ---- parse / categorize --------------------------------------------------------------------

def parse_map(path: Path) -> "OrderedDict[str, str]":
    items: "OrderedDict[str, str]" = OrderedDict()
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip() or line.startswith("#") or "::" not in line:
            continue
        name, _, iid = line.rpartition("::")
        iid = iid.strip()
        if iid.isdigit():
            items[iid] = name.strip()
    return items


def parse_notes(path: Path) -> dict:
    """From the hand file: itemId -> ALLCAPS note prefix (e.g. WARNING_ACCOUNT_CORRUPTION)."""
    notes = {}
    if not path.exists():
        return notes
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "::" not in line:
            continue
        name, _, iid = line.rpartition("::")
        m = NOTE_RE.match(name)
        if iid.strip().isdigit() and m:
            notes[iid.strip()] = m.group(1)
    return notes


def category(iid: str) -> str:
    return iid[:4] if len(iid) == 10 else iid[:3]


def render(items, notes, with_headers=True) -> str:
    buckets = defaultdict(list)
    for iid, name in items.items():
        buckets[category(iid)].append((iid, name))
    lines = []
    for prefix in sorted(buckets, key=lambda p: (int(p), p)):
        rows = sorted(buckets[prefix], key=lambda r: (r[1].lower(), r[0]))
        if with_headers:
            label = CATEGORY_NAMES.get(prefix, f"Uncategorized ({prefix})")
            lines.append(f"# === {label} ({prefix}) -- {len(rows)} items ===")
        for iid, name in rows:
            note = notes.get(iid)
            if note is None and category(iid) in DANGER_PREFIXES:
                note = "WARNING_ACCOUNT_CORRUPTION"
            lines.append(f"{note}_{name}::{iid}" if note else f"{name}::{iid}")
        lines.append("")  # blank line between categories (matches the hand-file layout)
    return "\n".join(lines).rstrip("\n") + "\n"


def print_summary(items, notes, hand_items):
    buckets = defaultdict(int)
    for iid in items:
        buckets[category(iid)] += 1
    print(f"\nitems: {len(items)}   categories: {len(buckets)}")
    print(f"{'prefix':<7}{'count':>7}  category")
    for prefix in sorted(buckets, key=lambda p: (int(p), p)):
        label = CATEGORY_NAMES.get(prefix, "Uncategorized")
        new = "" if prefix in CATEGORY_NAMES else "   <-- NEW prefix, name me in CATEGORY_NAMES"
        flag = " [!] " if prefix in DANGER_PREFIXES else "   "
        print(f"{prefix:<7}{buckets[prefix]:>7}{flag}{label}{new}")
    if hand_items:
        new_ids = set(items) - set(hand_items)
        hand_only = set(hand_items) - set(items)
        renamed = [i for i in set(items) & set(hand_items)
                   if i not in notes and items[i] != hand_items[i]]
        print(f"\nvs {HAND_FILE}: +{len(new_ids)} new ids, {len(renamed)} renamed, "
              f"{len(hand_only)} hand-only")
        if hand_only:
            shown = sorted(hand_only)[:12]
            print("  hand-only ids (not in dump): " + ", ".join(shown)
                  + (" ..." if len(hand_only) > 12 else ""))


# ---- main ----------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-pull", action="store_true",
                    help="skip adb; just re-sort the local ae_item_map.txt")
    ap.add_argument("--no-headers", action="store_true",
                    help="omit '# category' headers (pure name::id, like the hand file)")
    ap.add_argument("--package", default=PACKAGE, help="game package (default: %(default)s)")
    ap.add_argument("--device-file", default=None, help="override the on-device dump path")
    args = ap.parse_args()

    raw = SCRIPT_DIR / RAW_OUT
    device_file = args.device_file or f"/data/data/{args.package}/files/ae_item_map.txt"

    if not args.no_pull:
        adb_bin = find_adb()
        serial = connect(adb_bin)
        pull_dump(adb_bin, serial, device_file, raw)
    if not raw.exists():
        sys.exit(f"{raw} not found. Run without --no-pull to fetch it from the device.")

    items = parse_map(raw)
    if not items:
        sys.exit(f"{raw} has no 'Name::id' lines -- did the in-game dump run?")

    hand_path = SCRIPT_DIR / HAND_FILE
    notes = parse_notes(hand_path)
    hand_items = parse_map(hand_path) if hand_path.exists() else {}

    out = SCRIPT_DIR / SORTED_OUT
    out.write_text(render(items, notes, with_headers=not args.no_headers), encoding="utf-8")
    print(f"wrote {out.name} ({len(items)} items)")
    print_summary(items, notes, hand_items)


if __name__ == "__main__":
    main()
