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
- **Arbeit im Raum** (automatisch, wer im Raum steht): erst Feuer löschen, dann Hüllenbrüche flicken (5 s), dann das System reparieren (1 Balken in 4 s). Mehrere Personen arbeiten schneller. Beschädigte Räume pulsieren rot, der gelbe Balken zeigt den Fortschritt.
- **Lebenspunkte** (100): Balken unter dem Porträt und über verletzten Figuren. Schaden durch Treffer im Raum (15 je Schadenspunkt), Feuer (5/s auf der Kachel, 1,5/s im Raum) und Ersticken (6/s unter 10 % Luft). Die Medbay heilt mit Energie 6/s je Balken. Bei 0 stirbt die Figur.

### Energie und Kampf

- **Energie** (Leiste unten): Spalte antippen = 1 Balken mehr, gedrückt halten oder Rechtsklick = 1 Balken weniger. Ganz links der Reaktor: gelb = frei, rot = zerstört. Bei Systemen: grün = versorgt, rot = beschädigt.
- **Startverteilung** (Reaktor 8): Lebenserhaltung 1, Schilde 2, Waffen 3, Antrieb 2. Sensoren und Medbay bleiben aus, bis du umschichtest.
- **Waffen** (Karten unten, nummeriert): Mit Energie lädt eine Waffe, ohne entlädt sie sich. Geladen feuert sie selbst auf ihr Ziel; ohne Ziel blinkt die Karte. Gedrückt halten oder Rechtsklick schaltet eine Waffe ein oder aus.
- **Zielen, alle Waffen:** einen Gegnerraum antippen (knapp daneben zählt auch)
- **Zielen, einzeln:** Waffenkarte antippen (rot umrandet), dann einen Gegnerraum. Den aktuellen Zielraum der Waffe erneut antippen hebt das Ziel auf. Fadenkreuze im Gegnerschiff tragen die Waffennummer.
- **Einschlag:** Ausweichen (Antrieb + besetztes Cockpit), sonst fängt der Schild ab (2 Balken = 1 Schicht, lädt in 2 s nach), sonst Treffer: Hülle und System im Raum verlieren Balken
- **Reaktortreffer** senken die verfügbare Energie; dann werden Systeme in der Reihenfolge Lebenserhaltung, Schilde, Waffen, Antrieb, Sensoren, Medbay versorgt. Nach der Reparatur kommt die gewünschte Energie von selbst zurück.
- **Gegner:** Hülle 14, Reaktor 8, zwei Schildschichten, Pulslaser und Bordkanone. Jede Waffe zielt alle paar Sekunden auf einen anderen Raum. Die Mechanikerin oder der Mechaniker löscht Feuer, flickt Lecks, repariert Systeme und kehrt danach zur Konsole zurück. Der Kutter hat keine Lebenserhaltung, aber eine eingebaute Luftaufbereitung (`oxygen_regen`).
- **Balance:** In 20 simulierten Kämpfen ohne Eingreifen gewinnt der Frachter 12. Wer Energie umschichtet, gezielt schießt und Feuer bekämpft, sollte klar besser abschneiden.
- **Treffer** können Feuer (35 %) und Hüllenbrüche (20 %) im Raum auslösen.
- **Sauerstoff** je Raum: Die Lebenserhaltung füllt nach (4 %/s je Balken). Feuer verbraucht Luft, Hüllenbrüche und offene Schleusen lassen sie entweichen. Räume mit wenig Luft färben sich rosa; „Luft“ oben rechts ist der Schnitt über alle Räume.
- **Feuer** (je Kachel): breitet sich bei mehr als 25 % Luft aus, im Raum und durch offene Türen; unter 12 % erlischt es. Es beschädigt das System im Raum.
- **Türen** antippen: auf oder zu (am Start alle zu). Offene Türen gleichen die Luft zwischen Räumen aus und lassen Feuer durch. Die eigene Crew läuft auch durch geschlossene Türen.
- **Luftschleusen** antippen (gelbe Luken auf der Außenwand, Frachter 2, Kutter 1): offen saugen sie den Raum in 2 s leer, über offene Türen auch die Nachbarräume. So erstickt man Feuer; eigene Crew sollte den Raum vorher verlassen.
- **Ende:** Hülle auf 0 oder ganze Crew tot. Danach antippen für einen neuen Kampf.

### Effekte

Flackernde Flammen mit Rauch, entweichende Luft an Lecks und offenen Schleusen, Dampf beim Löschen, Geschosse mit Mündungsfeuer, Schildblase mit Welle beim Abfangen, Explosion mit Funken und Rauch, Raumblitz, Bildschirmwackeln und roter Blitz bei eigenen Treffern, schwebende Texte (Schaden, „SCHILD“, „AUSGEWICHEN“, „REPARIERT“), Triebwerksflammen je nach Antriebsenergie, Explosionskette beim Zerstören. Alles ist in `scripts/view/` gezeichnet, ohne zusätzliche Grafikdateien.

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
