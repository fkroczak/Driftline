# Keelbreak – Godot-Projekt

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

## Android-APK

Gebaut wird nur auf ausdrücklichen Wunsch, nicht bei jedem Push oder Merge (Workflow `.github/workflows/android-apk.yml`):

- **Tag pushen** (geht von jedem Branch): `git tag apk-0.2 && git push origin apk-0.2`
- **Knopf auf GitHub:** Actions → „Android-APK bauen“ → „Run workflow“. Erscheint erst, wenn der Workflow auf `main` liegt.

Nach etwa 5 Minuten liegt die APK unter **Releases** als Vorabversion; am Handy herunterladen und installieren.

**Updates installieren:** Ohne festen Schlüssel wird jede APK neu signiert, dann muss die alte Version vorher deinstalliert werden. Abhilfe: einen Debug-Keystore als Base64 im Repository-Secret `ANDROID_DEBUG_KEYSTORE_BASE64` hinterlegen (Passwort `android`, Alias `androiddebugkey`).

Lokal aus dem Editor: Exportvorlagen und Android SDK in Godot einrichten, Handy per USB anschließen, oben rechts auf das Android-Symbol klicken (Remote Debug).
