# Driftline – Art-Styleguide

Ergänzt den [Stil-Brief](art-brief.md) um die Entscheidungen aus der Stilprobe.

## Maßstab

| Element | Größe | Verwendung |
|---|---|---|
| Kachel | 14 × 14 px | Grundraster im Schiff |
| Raum | 28 × 28 px (2 × 2 Kacheln) | Systeme, Erweiterungen |
| Crew klein | 16 × 16 px Canvas, Figur 13 px breit | Figur an Bord, belegt 1 Kachel |
| Crew groß | 40 × 44 px | Porträt in UI, Crew-Liste, Dialoge |
| Schiff | ca. 280 × 140 px | Schiffsansicht |

Entschieden: Im Schiff laufen die kleinen Figuren, die große Fassung ist das Porträt. Mit 40×44 px wäre eine Figur größer als ein ganzer Raum.

## Pipeline

1. Vektorvorlage (SVG) in Pixelkoordinaten der Zielgröße, gerendert mit Faktor 10.
2. **Abweichung vom Brief:** zuerst in hoher Auflösung auf die Palette quantisieren, dann je Pixelblock die häufigste Farbe nehmen. Andersherum (erst herunterrechnen, dann quantisieren) werden 1–2 px feine Linien zu Mischfarben. Die Variante laut Brief liegt als `process_box()` in `pipeline.py` bereit.
3. Alpha hart bei 50 %.
4. 1-px-Kontur `#0A0B16` (8er-Nachbarschaft).
5. Schlagschatten nach unten rechts: Kern Schwarz 40 % Deckkraft, 1-px-Rand 20 %. Versatz: Crew groß 2 px, Crew klein 1 px, Schiffe 3 px.
6. Export als 1× und ×4 (Nearest Neighbor), transparentes PNG.

**Kleine Crew:** Bei 14 px liefern Vektorformen nur Brei. Die Bord-Figur wird deshalb aus einer Materialkarte gebaut (`SMALL_MAP` in `crew_human.py`). Die Karte wird für jede Richtung gedreht und danach automatisch schattiert: Kanten oben und links hell, unten und rechts dunkel. So bleibt das Licht oben links, egal wohin die Figur schaut.

## Licht und Effekte

- Lichtquelle oben links. Verläufe liegen in Weltkoordinaten, drehen also nicht mit der Figur mit.
- Rumpf: 1,5 px helle Kante oben links (`#E6EAF0`), dunkle Kante unten rechts (`#5A6370`).
- Plattenfugen: dunkle Fuge, daneben unten bzw. rechts eine helle Kante.
- Leuchteffekte (Triebwerke, Positionslichter, Kommunikator): heller Kern, 1–2 px Rand in der Leuchtfarbe.
- Positionsleuchten: rot oben, grün unten.

## Palette

62 Farben, siehe `art/palette/` (`.gpl` lässt sich in GIMP und Aseprite laden). Die Grundtöne kommen aus dem Brief, ergänzt um hellere und dunklere Stufen. Der Hintergrund `#07080F` gehört nicht zur Sprite-Palette.

## Raumsymbole

12 × 12 px, im Raum zentriert, mit 1-px-Schattenkante nach unten rechts. Die Formen sind eigene Entwürfe und an keine anderen Spiele angelehnt.

| System | Farbe | Symbol |
|---|---|---|
| Reaktor | Orange `#EF9F27` | Energiekern mit Ring |
| Schilde | Blau `#378ADD` | Kuppelbögen über Grundlinie |
| Waffen | Rot `#E24B4A` | Fadenkreuz |
| Antrieb | Koralle `#D85A30` | Doppelchevron |
| Cockpit | Türkis `#5DCAA5` | Steuerhorn |
| Medbay | Grün `#639922` | Kreuz (bewusst grün, nicht rot) |
| Sensoren | Violett `#7F77DD` | Signalbögen |
| Lebenserhaltung | Hellblau `#85B7EB` | aufsteigende Blasen |
| Vorinstalliertes Modul | Pink `#D4537E` | je Modul eigenes Symbol (offen) |
| Leerer Erweiterungsraum | Dunkelgrau mit Schraffur | hellgraues „+“ |

## Design-Regeln

- Keine Designs, Namen oder Symbole aus FTL, Star Wars oder Star Trek.
- Beispiel: Die C-Form des Mensch-Frachters öffnet zum Heck. Zwei Arme nach vorn mit Lücke würden an ein bekanntes Filmschiff erinnern.
