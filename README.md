# Driftline

Raumschiff-Roguelike für Android in Draufsicht, inspiriert von FTL, mit realistischer Pixel-Art. Du führst ein Schiff mit Crew aus sechs Spezies durch prozedural erzeugte Universen: Energie verteilen, kämpfen, reparieren, ausbauen, Planeten erkunden. Arbeitstitel, Konzeptphase.

## Inhalt

| Pfad | Inhalt |
| --- | --- |
| [docs/GDD.md](docs/GDD.md) | Game-Design-Dokument: Kernschleife, Kampf, Energie, Spezies, Schiffe, Module, Spielmodi, Roadmap |
| [docs/fable-prompt.md](docs/fable-prompt.md) | Prompt für die Grafik-Erstellung (Crew-Sprites und 12 Schiffe) |
| [art/](art/README.md) | Konzeptgrafiken, Pixel-Art-Proben und deren Quelldateien |
| [tools/pixelize.py](tools/pixelize.py) | Wandelt eine SVG-Zeichnung in Pixel-Art um (Palette, Kontur, Schatten) |
| [docs/art-styleguide.md](docs/art-styleguide.md) | Styleguide: Maßstab (Kachel 14 px, Crew 14 px an Bord / 40×44 Porträt), feste Palette, Pipeline, Raumsymbole |
| [docs/referenz-notizen.md](docs/referenz-notizen.md) | Beobachtungen aus dem Genre-Vorbild: Screens, HUD, Tooltips, Touch-Umsetzung |
| [docs/schiffe/](docs/schiffe/mensch-frachter.md) | Raumlisten der Schiffe |
| [tools/artgen/](tools/artgen/build.py) | Sprite-Pipeline mit fester 62-Farben-Palette; `python3 tools/artgen/build.py` erzeugt `art/export`, `art/preview`, `art/palette` |

## Eckdaten

- **Engine:** Godot 4, Export als Android-App (Querformat)
- **Spielmodi:** „Die Jagd“ (10 Sprünge pro Universum, Endboss) und „Endloses Universum“ (Fraktionen, Highscore)
- **Ressourcen:** Treibstoff ist Währung und kostet 1 pro Sprung; Rohstoffe für Upgrades und Reparatur
- **Stil:** realistische HD-Pixel-Art, Palette mit ca. 64 Farben, dunkle Konturen

Mechaniken sind frei nutzbar; Namen, Grafiken und Texte aus FTL, Star Wars oder Star Trek werden nicht übernommen.
