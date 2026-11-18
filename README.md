# Driftline

Raumschiff-Roguelike für Android in Draufsicht, inspiriert von FTL, mit realistischer Pixel-Art. Du führst ein Schiff mit Crew aus sechs Spezies durch prozedural erzeugte Universen: Energie verteilen, kämpfen, reparieren, ausbauen, Planeten erkunden. Arbeitstitel, Konzeptphase.

## Inhalt

| Pfad | Inhalt |
| --- | --- |
| [docs/GDD.md](docs/GDD.md) | Game-Design-Dokument: Kernschleife, Kampf, Energie, Spezies, Schiffe, Module, Spielmodi, Roadmap |
| [docs/fable-prompt.md](docs/fable-prompt.md) | Prompt für die Grafik-Erstellung (Crew-Sprites und 12 Schiffe) |
| [art/](art/README.md) | Konzeptgrafiken, Pixel-Art-Proben und deren Quelldateien |
| [tools/pixelize.py](tools/pixelize.py) | Wandelt eine SVG-Zeichnung in Pixel-Art um (Palette, Kontur, Schatten) |

## Eckdaten

- **Engine:** Godot 4, Export als Android-App (Querformat)
- **Spielmodi:** „Die Jagd“ (10 Sprünge pro Universum, Endboss) und „Endloses Universum“ (Fraktionen, Highscore)
- **Ressourcen:** Treibstoff ist Währung und kostet 1 pro Sprung; Rohstoffe für Upgrades und Reparatur
- **Stil:** realistische HD-Pixel-Art, Palette mit ca. 64 Farben, dunkle Konturen

Mechaniken sind frei nutzbar; Namen, Grafiken und Texte aus FTL, Star Wars oder Star Trek werden nicht übernommen.
