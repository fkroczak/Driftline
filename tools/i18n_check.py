#!/usr/bin/env python3
"""Prüft die Übersetzungen in game/i18n/<sprache>.json.

Schlüssel sind die deutschen Texte. Gesammelt werden:
- jedes Loc.t("…") in game/scripts,
- `label = "…"` von HudButtons in game/scenes,
- Texte in Konstanten, deren Zeilen mit `# i18n` markiert sind (ohne IDs: erstes Element
  einer Liste `["id", …]`, Farben und Dictionary-Schlüssel `"key": …`),
- Texte aus den Spieldaten (Schiffe, Räume, Spezies, Waffen, Gegner, Ereignisse, Startauswahl).

Aufruf:  python3 tools/i18n_check.py [sprache]          (Standard: en)
         python3 tools/i18n_check.py en --missing-json  (fehlende Schlüssel als JSON-Vorlage)
Exit-Code 1, wenn Schlüssel fehlen oder Platzhalter (%d, %s …) nicht zusammenpassen.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "game"
LITERAL = r'"((?:[^"\\]|\\.)*)"'
LOC_CALL = re.compile(r'Loc\.t\(' + LITERAL + r'\)')
ANY_LITERAL = re.compile(r'(\[\s*|Color\()?' + LITERAL + r'(\s*:)?')
PLACEHOLDER = re.compile(r'%[+\-0-9.]*[dsf%]')
NOT_TEXT = {"left", "right", ""}


def unescape(s: str) -> str:
    return s.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')


def keys_from_scripts() -> dict:
    found = {}
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            where = f"{path.relative_to(ROOT)}:{no}"
            for m in LOC_CALL.finditer(line):
                found.setdefault(unescape(m.group(1)), where)
            if line.rstrip().endswith("# i18n"):
                for m in ANY_LITERAL.finditer(line.split("# i18n")[0]):
                    if m.group(1) or m.group(3):
                        continue  # ID am Listenanfang, Farbe oder Dictionary-Schlüssel
                    text = unescape(m.group(2))
                    if text not in NOT_TEXT:
                        found.setdefault(text, where)
    for path in sorted((ROOT / "scenes").glob("*.tscn")):
        for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            m = re.match(r'label = ' + LITERAL + r'$', line)
            if m:  # HudButton übersetzt sein label selbst
                found.setdefault(unescape(m.group(1)), f"{path.relative_to(ROOT)}:{no}")
    return found


def keys_from_data() -> dict:
    found = {}
    data = ROOT / "data"

    def add(text, where):
        if isinstance(text, str) and text.strip():
            found.setdefault(text, where)

    for path in sorted((data / "ships").glob("*.json")):
        d = json.loads(path.read_text(encoding="utf-8"))
        where = f"data/ships/{path.name}"
        for key in ("name", "role", "description"):
            add(d.get(key), where)
        for room in d.get("rooms", []):
            add(room.get("name"), where)
    for sid, d in json.loads((data / "species.json").read_text(encoding="utf-8")).items():
        if sid.startswith("_"):
            continue
        add(d.get("name"), "data/species.json")
        add(d.get("lore"), "data/species.json")
        for t in d.get("traits", []):
            add(t, "data/species.json")
    for wid, d in json.loads((data / "weapons.json").read_text(encoding="utf-8")).items():
        if not wid.startswith("_"):
            add(d.get("name"), "data/weapons.json")
            add(d.get("text"), "data/weapons.json")
    for pid, d in json.loads((data / "upgrades.json").read_text(encoding="utf-8")).get("perks", {}).items():
        add(d.get("name"), "data/upgrades.json")
        add(d.get("text"), "data/upgrades.json")
    loadout = json.loads((data / "loadout.json").read_text(encoding="utf-8"))
    for section in ("ships", "difficulties"):
        for d in loadout.get(section, {}).values():
            add(d.get("name"), "data/loadout.json")
            add(d.get("text"), "data/loadout.json")
    enemies = json.loads((data / "enemies.json").read_text(encoding="utf-8"))
    for key in ("hunter", "boss"):
        add(enemies.get(key, {}).get("name"), "data/enemies.json")
    for e in json.loads((data / "events.json").read_text(encoding="utf-8"))["events"]:
        where = f"data/events.json#{e['id']}"
        add(e.get("title"), where)
        add(e.get("text"), where)
        add(e.get("quest"), where)
        for c in e.get("choices", []):
            add(c.get("text"), where)
            for o in c.get("outcomes", []):
                add(o.get("text"), where)
    return found


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    lang = args[0] if args else "en"
    table_path = ROOT / "i18n" / f"{lang}.json"
    table = json.loads(table_path.read_text(encoding="utf-8")) if table_path.exists() else {}
    table = {k: v for k, v in table.items() if not k.startswith("_")}
    wanted = keys_from_scripts()
    wanted.update({k: v for k, v in keys_from_data().items() if k not in wanted})

    missing = {k: w for k, w in wanted.items() if not table.get(k)}
    unused = [k for k in table if k not in wanted]
    bad = [k for k, v in table.items()
           if v and sorted(PLACEHOLDER.findall(k)) != sorted(PLACEHOLDER.findall(v))]

    if "--missing-json" in sys.argv:
        print(json.dumps({k: "" for k in missing}, ensure_ascii=False, indent=2))
        return 1 if missing else 0
    for k, w in missing.items():
        print(f"FEHLT   {w}: {k!r}")
    for k in bad:
        print(f"PLATZHALTER passen nicht: {k!r} -> {table[k]!r}")
    for k in unused:
        print(f"UNBENUTZT {k!r}")
    print(f"{lang}: {len(wanted)} Texte, {len(missing)} fehlen, {len(bad)} mit falschen Platzhaltern, {len(unused)} unbenutzt")
    return 1 if missing or bad else 0


if __name__ == "__main__":
    sys.exit(main())
