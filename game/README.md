# Driftline – Godot-Projekt

Prototyp Phase 1 (siehe [GDD](../docs/GDD.md#technik-und-roadmap)): Die Frage ist, ob der Kampf per Touch Spaß macht.

**Stand:** Der Mensch-Frachter mit drei Crewmitgliedern. Figur antippen, dann Zielraum antippen; die Figur läuft durch die Türen dorthin. Rechtsklick hebt die Auswahl auf.

## Öffnen und starten

1. [Godot 4.7](https://godotengine.org/download) installieren (Standard-Version, nicht .NET)
2. In Godot „Importieren“ → `game/project.godot` wählen
3. F5 startet das Spiel

## Aufbau

Logik und Darstellung sind getrennt, damit Spielregeln testbar bleiben und Eingabe (Touch, Maus, Controller) austauschbar ist.

| Pfad | Inhalt |
| --- | --- |
| `data/ships/*.json` | Schiffslayouts: Raster, Räume, Türen als Kachelpaare |
| `scripts/core/` | Reine Spiellogik ohne Nodes: `ShipLayout` (Raster, Wegfindung), `CrewMember`, `ShipState` |
| `scripts/view/` | Darstellung und Eingabe: `ShipView` zeichnet Schiff und Crew, übersetzt Antippen in Befehle |
| `scenes/main.tscn` | Startszene |
| `assets/` | Kopien aus `art/export/1x` |
| `tests/run_tests.gd` | Logiktests |

**Grafik aktualisieren:** Nach `python3 tools/artgen/build.py` die benötigten PNGs aus `art/export/1x/` nach `game/assets/` kopieren.

## Tests

```sh
godot --headless --path game --import                       # einmalig nach dem Klonen
godot --headless --path game --script res://tests/run_tests.gd
```

## Darstellung

Basisauflösung 640 × 360, ganzzahlig hochskaliert (Full HD: 3×), Querformat, Pixel-Art ohne Filter. Renderer „Compatibility“ für ältere Android-Geräte.

Offen: Ein Raum ist bei 3× etwa 33 dp groß, das GDD verlangt mindestens 48 dp. Das klären wir beim ersten Test auf dem Handy.

## Android-Export (später)

In Godot: Editor → Exportvorlagen verwalten → herunterladen; Android SDK und Debug-Keystore in den Editor-Einstellungen eintragen; Projekt → Exportieren → Android hinzufügen. Für schnelles Testen „Remote Debug“ mit per USB verbundenem Handy.
