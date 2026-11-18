# Referenz-Notizen (Genre-Vorbild)

Beobachtungen aus Screenshots des Genre-Vorbilds. Gedacht als Liste der Funktionen, die Driftline braucht. **Optik, Namen und Symbole werden nicht übernommen**, siehe [Styleguide](art-styleguide.md). Die Screenshots selbst liegen bewusst nicht in der Repo.

## Schiffsansicht

- Der Raumplan ist eine eigene Ebene über einem deutlich größeren Rumpf. Der Rumpf hat Volumen (Aufbauten, Gondeln), die Räume nehmen grob 60 % der Fläche ein.
  → Driftline: Schiffe etwa 360 × 180 px, Kachel bleibt 14 px.
- Raumgrößen gemischt: 2×2 für Systeme, 1×2 bzw. 2×1 für Gänge und Nebenräume.
  → Driftline: Systeme 2×2, zusätzlich 1×2-Räume erlauben.
- Waffen hängen sichtbar außen an Hardpoints. Die Schildblase ist ein eigener Effekt um das ganze Schiff.
  → Driftline: eigene Schildoptik, kein Wabenmuster.
- Türen sind kleine Doppelbalken auf den Wänden.
- Ein Raum unter der Maus oder ein ausgewählter Raum bekommt einen farbigen Rahmen.

## Crew an Bord

- Eine Figur belegt etwa 1 Kachel, bis zu 4 Figuren passen in einen 2×2-Raum. In Driftline umgesetzt.
- Eine ausgewählte Figur bekommt eine farbige Kontur.
  → Driftline: Auswahlzustand automatisch aus der Pipeline, mit heller statt dunkler Kontur.
- Über verletzten oder ausgewählten Figuren steht ein Lebensbalken.
  → Driftline: 1 px hoch über dem Kopf.
- Tooltip auf einer Figur: voller Name, Spezies, Gesundheit, Eigenschaften der Spezies.

## Crew-Liste und Fähigkeiten

- Liste am linken Rand: Mini-Porträt, Name, Lebensbalken, Hotkey.
- Tooltip mit 6 Fähigkeiten und Balken: Steuern, Antrieb, Schilde, Waffen, Reparatur, Kampf. Der stärkste Wert ist hervorgehoben.
  → Driftline: 6 eigene Fähigkeiten-Icons, 12 px groß.

## Weitere Screens

- **Schiff aufrüsten:** Systeme als Spalten mit Energiebalken und Kosten; Subsysteme; Reaktor-Ausbau.
- **Crew:** Karten mit Porträt, Name und „Entlassen“. Hier kommt das Porträt mit 40 × 44 px zum Einsatz.
- **Ausrüstung:** Waffen, Drohnen, Fracht, Ausbauten, jeweils mit Gegenstandsbild (etwa 48 × 32 px).
- **HUD:** Hülle, Schilde, Treibstoff, Raketen, Drohnenteile, Währung, Energie, Waffenleiste, Sprungknopf.

## Abgrenzung

- Keine Namen aus dem Vorbild, also kein „FTL-Antrieb“, keine Waffen- oder Spezies-Namen. Stattdessen etwa „Sprungantrieb“.
- Keine Rahmenoptik mit abgeschrägten Kanten, Cyan-Leuchtrand und rosa Feldern.
- Spezies-Eigenschaften selbst entwerfen. Vor allem die Androiden dürfen nicht die Werte der Roboter-Spezies im Vorbild übernehmen (doppelte Reparatur, halber Schaden).
