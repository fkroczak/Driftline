# Prompt für die Grafik-Erstellung (Fable)

Diesen Prompt an Fable übergeben, um Crew-Sprites und Schiffe im Hullbound-Stil erstellen zu lassen.

````
Du bist Pixel-Art-Designer für ein Android-Spiel. Erstelle Grafiken für "Hullbound", ein Raumschiff-Roguelike in Draufsicht (inspiriert von FTL, aber mit komplett eigenen Designs). Wichtig: Keine Designs, Namen oder Symbole aus FTL, Star Wars oder Star Trek kopieren. Stimmung: glaubwürdige, funktionale Raumfahrttechnik.

## Stil
- Realistische HD-Pixel-Art: echte Proportionen, Materialien und Licht (Lichtquelle oben links), aber als echte Pixelgrafik
- Feste Palette mit ca. 64 Farben (siehe unten), keine Verläufe, kein Anti-Aliasing im Endergebnis
- 1 Pixel dunkle Kontur (#0A0B16) um jede Figur und jedes Schiff
- Weicher Schlagschatten (Hintergrund um ca. 40 % abgedunkelt), versetzt nach unten rechts
- Leuchteffekte (Triebwerke, Visiere, Kristalle, Reaktor) als 1–2 Pixel breiter, aufgehellter Rand in der Leuchtfarbe
- Alles in Draufsicht; Figuren schauen standardmäßig nach unten

## Arbeitsweise
1. Jedes Motiv zuerst als detaillierte Vektorzeichnung (SVG) in hoher Auflösung anlegen
2. Auf Zielauflösung herunterrechnen (Crew: ca. 40×44 px, Schiffe: ca. 280×140 px)
3. Auf die feste Palette quantisieren (ohne Dithering), Alpha bei 50 % hart abschneiden
4. 1-px-Kontur ergänzen, dann mit Nearest-Neighbor ×4 hochskalieren
5. Als PNG mit transparentem Hintergrund liefern, plus eine Vorschau auf dunklem Weltraum (#07080F)

## Palette (Grundtöne, jeweils 3–4 Abstufungen hell bis dunkel ergänzen)
Rumpf-Grau #C4CAD3 #8E97A4 #5A6370 #2A2F3A · Bodenfliesen #20263A #2B3249
Blau #85B7EB #378ADD #185FA5 · Türkis #9FE1CB #5DCAA5 #0F6E56
Grün #C0DD97 #639922 #3B6D11 · Orange #FAC775 #EF9F27 #854F0B
Rot #F7C1C1 #E24B4A #A32D2D · Koralle #F0997B #D85A30
Violett #CECBF6 #7F77DD #534AB7 #26215C · Pink #F4C0D1 #D4537E
Braun #B07A3C #7F4C1E #5E3614 · Haut #E2AC8B #C58A6A

## Raumsymbole (feste Farben, gut unterscheidbar)
Reaktor Orange · Schilde Blau · Waffen Rot · Antrieb Koralle · Cockpit Türkis · Medbay Grün · Sensoren Violett · Lebenserhaltung Hellblau · vorinstalliertes Modul Pink · leerer Erweiterungsraum Dunkelgrau mit diagonaler Schraffur und hellgrauem „+“

## Crew – 6 Spezies (je 4 Blickrichtungen: unten, oben, links, rechts)
Gleiche Silhouette pro Spezies, aber 3 Farbvarianten pro Spezies (Individuen).
1. Mensch: Haarschopf, schmaler Streifen Gesicht, Uniform-Schultern, Arme seitlich
2. Kith'ra (Insektoid): länglicher Körper mit geäderten Flügeldecken, 4 dünne Beine seitlich, 2 Fangarme nach vorne, dreieckiger Kopf mit roten Facettenaugen, Fühler
3. Androide: abgerundete Metallplatten, Schulterkappen, segmentierte Arme, leuchtender blauer Brustkern, Kopf mit türkisem Visier, rote Antennenleuchte
4. Veyari (intelligent, schwach): riesiger heller Schädel mit Mittelkamm, große dunkle Mandelaugen, schmaler violetter Robenkörper, dünne Arme, Datentablet
5. Ormok (riesig, stark): fast doppelt so breit, massige Schultern, Panzerplatte mit Nieten, kleiner Kopf vorne mit Hauern, riesige Fäuste
6. Petrani (Silizium): Steinkörper mit Facetten, je ein Kristall auf den Schultern (links türkis, rechts violett), glühender Kern in der Brust mit Rissen, kantiger Steinkopf mit bernsteinfarbenen Augen

## Schiffe – 12 Stück (Bug nach rechts, Räume als Raster sichtbar, 1 Raum = 2×2 Kacheln)
Jedes Schiff: eigene Silhouette, Plattenfugen, Fensterreihen, rote Positionsleuchte oben, grüne unten, leuchtende Triebwerke am Heck.
| Schiff | Form und Optik | Erweiterungsräume | Start-Modul |
| Mensch Frachter | C-Form mit Shuttlebucht in der Öffnung, grau-blau | 3 | – |
| Mensch Flottenkreuzer | schlanker Keil, dunkelblau, rote Streifen, 4 Geschütztürme | 2 | – |
| Kith'ra Schwarmschiff | ovaler, segmentierter Chitinpanzer, grün, Drohnen am Rumpf | 2 | Drohnensteuerung |
| Kith'ra Kaperschiff | brauner Panzer mit 2 Fangklauen am Bug | 2 | Teleporter |
| Androide Modulwürfel | blockig aus weißen Modulen, türkise Leuchtlinien | 3 | – |
| Androide Ionenjäger | dunkler Pfeil mit Heckflossen, blaue Ionenspitze | 2 | Hacking |
| Veyari Forschungsschiff | elegantes Oval, violett mit Goldkanten, Sensorring am Bug | 2 | Labor |
| Veyari Lanzenschiff | 7-Form: langer Rumpf, Ausleger zu einer goldenen Strahlenlanze | 1 | – |
| Ormok Schrottkoloss | unförmig, aufgeschweißte Rost- und Metallplatten, Nieten | 3 | – |
| Ormok Rammbock | Keil mit dicker Frontpanzerung und Metall-Rammsporn | 1 | – |
| Petrani Asteroidenschiff | ausgehöhlter Asteroid mit Kratern, Kristallen, glühenden Heckrissen; keine Lebenserhaltung | 2 | Raffinerie |
| Petrani Kristallresonator | Bündel aus Kristallsäulen, leuchtende Kristallspitze am Bug | 1 | – |

Pflicht-Räume (wo sinnvoll): Cockpit, Reaktor, Schilde, Waffen, Antrieb, Medbay, Lebenserhaltung (nicht bei Petrani-Schiffen), optional Sensoren.

## Lieferung
1. Zuerst nur Mensch (Crew, alle 4 Richtungen) und Mensch Frachter als Stilprobe, dann auf mein Feedback warten
2. Danach Crew-Spritesheet (6 Spezies × 4 Richtungen × 3 Varianten) und ein Bild pro Schiff
3. Zu jedem Schiff eine kurze Liste der Räume und ihrer Position
````
