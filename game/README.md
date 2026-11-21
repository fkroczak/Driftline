# Hullbound – Godot-Projekt

Prototyp Phase 1 (siehe [GDD](../docs/GDD.md#technik-und-roadmap)): Die Frage ist, ob der Kampf per Touch Spaß macht.

**Stand:** Der Mensch-Frachter mit drei Crewmitgliedern und einer Crew-Leiste links.

- **Auswählen:** Figur im Schiff (knapp daneben zählt auch) oder Porträt in der Leiste antippen; eine andere Figur antippen wechselt die Auswahl
- **Schicken:** danach eine freie Kachel antippen; die Figur läuft genau dorthin, die Auswahl endet
- **Verdrängen:** auf einer besetzten Kachel gedrückt halten; wer dort steht, weicht auf die nächste freie Kachel aus
- **Abwählen:** die ausgewählte Figur erneut antippen oder neben das Schiff tippen
- **Konsolen** (Antrieb, Schilde, Sensoren, Waffen, Cockpit; kleine Leiste an der Kachel, grün = besetzt):
  1. Ist die Konsole frei, setzt sich die erfahrenste Person im Raum hin.
  2. Sitzt dort jemand weniger Erfahrenes, tauschen beide, außer diese Person wurde ausdrücklich an die Konsole geschickt.
  3. An der Konsole steigt die Erfahrung im System (1 Stufe pro Minute, höchstens 5). Die Punkte unter dem Porträt zeigen die Stufe im aktuellen Raum.

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

Basisauflösung 384 × 216, ganzzahlig hochskaliert (1080p: 5×), Breite passt sich dem Seitenverhältnis an, Querformat, Pixel-Art ohne Filter. Renderer „Compatibility“ für ältere Android-Geräte.

Ein Raum ist bei 5× auf einem 1080p-Handy 140 px groß (ca. 56 dp, GDD: mindestens 48 dp), eine Kachel 70 px. Hintergrund: Sternenfeld in drei Ebenen (`scripts/view/starfield.gd`).

## Android-APK

Gebaut wird nur auf ausdrücklichen Wunsch, nicht bei jedem Push oder Merge (Workflow `.github/workflows/android-apk.yml`):

- **Tag pushen** (geht von jedem Branch): `git tag apk-0.2 && git push origin apk-0.2`
- **Knopf auf GitHub:** Actions → „Android-APK bauen“ → „Run workflow“. Erscheint erst, wenn der Workflow auf `main` liegt.

Nach etwa 5 Minuten liegt die APK unter **Releases** als Vorabversion; am Handy herunterladen und installieren.

**Updates installieren:** Ohne festen Schlüssel wird jede APK neu signiert, dann muss die alte Version vorher deinstalliert werden. Abhilfe: einen Debug-Keystore als Base64 im Repository-Secret `ANDROID_DEBUG_KEYSTORE_BASE64` hinterlegen (Passwort `android`, Alias `androiddebugkey`).

Lokal aus dem Editor: Exportvorlagen und Android SDK in Godot einrichten, Handy per USB anschließen, oben rechts auf das Android-Symbol klicken (Remote Debug).
