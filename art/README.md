# Grafiken

## pixel/ – aktueller Stil (realistische Pixel-Art)

| Datei | Inhalt |
| --- | --- |
| `species_pixel.png` | Die sechs Spezies in Draufsicht: Mensch, Kith'ra, Androide, Veyari, Ormok, Petrani |
| `ships_pixel.png` | Schiffsentwürfe in C-Form (mit Shuttlebucht) und 7-Form (mit Geschützausleger) |
| `sprungkarte_pixel.png` | Sprungkarte im Jagd-Modus: Nebel, Sprungziele, Jägerfront, Infofeld |
| `hud_kampf_pixel.png` | Kampf-HUD im Querformat: eigenes Schiff, Gegner, Energie, Waffen, Crew |
| `hud_ereignis_pixel.png` | Ereignis-Dialog mit Spezies-Option, Spiel pausiert |

## source/ – Quelldateien der Pixel-Art

Detaillierte SVG-Zeichnungen, aus denen die PNGs erzeugt werden:

```sh
python3 tools/pixelize.py art/source/species_realistic.svg art/pixel/species_pixel.png 216 160 5 56 floor
python3 tools/pixelize.py art/source/ships_c_7_form.svg art/pixel/ships_pixel.png 285 279 4 120 space
```

Die UI-Mockups entstehen mit `art/source/ui/render.py` (Sprungkarte) und `art/source/ui/hud.py` (Kampf-HUD und Ereignis-Dialog); beide im Ordner `art/source/ui` ausführen, `hud.py` erwartet die gerenderten Schiffskonzepte `s1.png` und `s5.png`.

Parameter: Quelle, Ziel, Breite und Höhe in Pixeln, Hochskalierung, Farbanzahl, Hintergrund (`floor` oder `space`). Benötigt `rsvg-convert` und Pillow.

Bekannte Schwäche: Die automatisch berechnete Palette lässt kleine Raumsymbole farblich verschmelzen (Antrieb und Modul wirken beide rot). Nächster Schritt ist eine feste Palette.

## concepts/ – erste Konzepte der 12 Speziesschiffe

Je zwei Schiffe pro Spezies, noch im einfacheren 16-Bit-Stil, aber mit den gültigen Raumlayouts:

| Farbe | Raum |
| --- | --- |
| Orange | Reaktor |
| Blau | Schilde |
| Rot | Waffen |
| Koralle | Antrieb |
| Türkis | Cockpit |
| Grün | Medbay |
| Lila | Sensoren |
| Hellblau | Lebenserhaltung |
| Pink | vorinstalliertes Modul |
| Grau mit „+“ | leerer Erweiterungsraum |

Diese Schiffe sollen im realistischen Pixel-Stil neu gezeichnet werden (siehe [docs/fable-prompt.md](../docs/fable-prompt.md)).

## export/, preview/, palette/ – Sprites aus der festen Palette

Erzeugt mit `python3 tools/artgen/build.py` (Pipeline in `tools/artgen/`, Details im [Styleguide](../docs/art-styleguide.md)). Diese Pipeline nutzt die feste Palette mit 62 Farben aus `palette/` und löst damit das oben genannte Problem verschmelzender Raumsymbole.

| Pfad | Inhalt |
| --- | --- |
| `export/1x/`, `export/4x/` | Spielfertige PNGs (transparent): Crew aller sechs Spezies groß 40×44 und klein 16×16 je 4 Richtungen (Mensch: `crew_human.py`, übrige: `crew_species.py`), Mensch-Frachter 280×140, Gegnerschiffe Plünderer, Kanonenboot und Jäger-Fregatte (`ship_enemies.py`, neu bauen mit `python3 tools/artgen/build.py gegner`, gibt die Grafikpunkte fürs Schiffs-JSON aus) |
| `preview/` | Vorschauen auf #07080F, u. a. Frachter mit Crew an Bord, `spezies_crew.png` (alle Spezies groß und klein) |
| `palette/` | Palette als `.gpl`, `.hex`, `.png` |
| `source/crew/`, `source/ships/` | SVG-Quellen dieser Sprites (werden vom Build überschrieben) |
