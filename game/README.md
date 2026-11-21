# Hullbound – Godot-Projekt

Prototyp Phase 1 (siehe [GDD](../docs/GDD.md#technik-und-roadmap)): Die Frage ist, ob der Kampf per Touch Spaß macht.

**Stand:** Der Mensch-Frachter mit drei Crewmitgliedern kämpft gegen einen Piratenkutter. Links die Crew-Leiste, unten Energie und Waffen, oben rechts Hülle, Schild und Ausweichchance.

### Crew

- **Auswählen:** Figur im Schiff (knapp daneben zählt auch) oder Porträt in der Leiste antippen; eine andere Figur antippen wechselt die Auswahl
- **Schicken:** danach eine freie Kachel antippen; die Figur läuft genau dorthin, die Auswahl endet
- **Verdrängen:** auf einer besetzten Kachel gedrückt halten; wer dort steht, weicht auf die nächste freie Kachel aus
- **Abwählen:** die ausgewählte Figur erneut antippen oder neben das Schiff tippen
- **Konsolen** (Antrieb, Schilde, Sensoren, Waffen, Cockpit; kleine Leiste an der Kachel, grün = besetzt):
  1. Ist die Konsole frei, setzt sich die erfahrenste Person im Raum hin.
  2. Sitzt dort jemand weniger Erfahrenes, tauschen beide, außer diese Person wurde ausdrücklich an die Konsole geschickt.
  3. An der Konsole steigt die Erfahrung im System (1 Stufe pro Minute, höchstens 5). Die Punkte unter dem Porträt zeigen die Stufe im aktuellen Raum.
  4. Eine besetzte Konsole beschleunigt das System: +10 % plus 5 % je Erfahrungsstufe (Schilde laden, Waffen laden, Ausweichen).
- **Reparieren:** Wer in einem Raum mit beschädigtem System steht, repariert es (1 Balken in 4 s, mehrere Personen schneller). Beschädigte Räume pulsieren rot, der gelbe Balken zeigt den Fortschritt.

### Energie und Kampf

- **Energie** (Leiste unten): Spalte antippen = 1 Balken mehr, gedrückt halten oder Rechtsklick = 1 Balken weniger. Ganz links der Reaktor: gelb = frei, rot = zerstört. Bei Systemen: grün = versorgt, rot = beschädigt.
- **Startverteilung** (Reaktor 8): Lebenserhaltung 1, Schilde 2, Waffen 3, Antrieb 2. Sensoren und Medbay bleiben aus, bis du umschichtest.
- **Waffen** (Karten unten): antippen schaltet eine Waffe ein oder aus. Mit Energie lädt sie, ohne entlädt sie sich. Geladen feuert sie selbst auf das Ziel; ohne Ziel blinkt die Karte.
- **Zielen:** einen Raum im Gegnerschiff antippen (knapp daneben zählt auch)
- **Einschlag:** Ausweichen (Antrieb + besetztes Cockpit), sonst fängt der Schild ab (2 Balken = 1 Schicht, lädt in 2 s nach), sonst Treffer: Hülle und System im Raum verlieren Balken
- **Reaktortreffer** senken die verfügbare Energie; dann werden Systeme in der Reihenfolge Lebenserhaltung, Schilde, Waffen, Antrieb, Sensoren, Medbay versorgt. Nach der Reparatur kommt die gewünschte Energie von selbst zurück.
- **Gegner:** zielt alle paar Sekunden auf einen anderen Raum. Seine Mechanikerin oder sein Mechaniker repariert Schäden und kehrt danach zur Konsole zurück.
- **Luftschleusen:** Gelb markierte Luken auf der Außenwand (Frachter: 2, Kutter: 1). Noch ohne Funktion; sie sollen später Sauerstoff ablassen, damit Feuer und Enterkommandos ersticken.
- **Ende:** Hülle auf 0. Danach antippen für einen neuen Kampf.

### Effekte

Geschosse mit Mündungsfeuer, Schildblase mit Welle beim Abfangen, Explosion mit Funken und Rauch, Raumblitz, Bildschirmwackeln und roter Blitz bei eigenen Treffern, schwebende Texte (Schaden, „SCHILD“, „AUSGEWICHEN“, „REPARIERT“), Triebwerksflammen je nach Antriebsenergie, Explosionskette beim Zerstören. Alles ist in `scripts/view/` gezeichnet, ohne zusätzliche Grafikdateien.

## Öffnen und starten

1. [Godot 4.7](https://godotengine.org/download) installieren (Standard-Version, nicht .NET)
2. In Godot „Importieren“ → `game/project.godot` wählen
3. F5 startet das Spiel

## Aufbau

Logik und Darstellung sind getrennt, damit Spielregeln testbar bleiben und Eingabe (Touch, Maus, Controller) austauschbar ist.

| Pfad | Inhalt |
| --- | --- |
| `data/ships/*.json` | Schiffe: Raster, Räume, Türen als Kachelpaare; Hülle, Reaktor, Systemstufen, Startenergie, Waffen, Grafikpunkte (Waffenmündung, Triebwerke, Schildblase) |
| `data/weapons.json` | Waffenwerte: Energie, Ladezeit, Schüsse, Schaden |
| `scripts/core/` | Reine Spiellogik ohne Nodes: `ShipLayout` (Raster, Wegfindung), `CrewMember`, `ShipSystem`, `Weapon`, `ShipState` (Energie, Schaden, Reparatur, Schilde), `Battle` (Schüsse, Einschläge, Gegner-KI, Ereignisse) |
| `scripts/view/` | Darstellung und Eingabe: `ShipView` (eigenes und Gegnerschiff), `Effects`, `PowerPanel`, `WeaponPanel`, `StatusBar`, `CrewPanel` |
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

Basisauflösung 384 × 216, ganzzahlig hochskaliert (1080p: 5×), Breite passt sich dem Seitenverhältnis an, Querformat, Pixel-Art ohne Filter. Typische Handys (20:9) zeigen 480 × 216; das Desktop-Fenster ist deshalb 1920 × 864 groß. Bei 16:9 (384 px) rücken die Schiffe eng zusammen. Renderer „Compatibility“ für ältere Android-Geräte.

Ein Raum ist bei 5× auf einem 1080p-Handy 140 px groß (ca. 56 dp, GDD: mindestens 48 dp), eine Kachel 70 px. Hintergrund: Sternenfeld in drei Ebenen (`scripts/view/starfield.gd`).

## Android-APK

Gebaut wird nur auf ausdrücklichen Wunsch, nicht bei jedem Push oder Merge (Workflow `.github/workflows/android-apk.yml`):

- **Tag pushen** (geht von jedem Branch): `git tag apk-0.2 && git push origin apk-0.2`
- **Knopf auf GitHub:** Actions → „Android-APK bauen“ → „Run workflow“. Erscheint erst, wenn der Workflow auf `main` liegt.

Nach etwa 5 Minuten liegt die APK unter **Releases** als Vorabversion; am Handy herunterladen und installieren.

**Updates installieren:** Ohne festen Schlüssel wird jede APK neu signiert, dann muss die alte Version vorher deinstalliert werden. Abhilfe: einen Debug-Keystore als Base64 im Repository-Secret `ANDROID_DEBUG_KEYSTORE_BASE64` hinterlegen (Passwort `android`, Alias `androiddebugkey`).

Lokal aus dem Editor: Exportvorlagen und Android SDK in Godot einrichten, Handy per USB anschließen, oben rechts auf das Android-Symbol klicken (Remote Debug).
