# Referenz-Notizen (Genre-Vorbild)

Beobachtungen aus Screenshots des Genre-Vorbilds. Gedacht als Liste der Funktionen, die Hullbound braucht. **Optik, Namen und Symbole werden nicht übernommen**, siehe [Styleguide](art-styleguide.md). Die Screenshots selbst liegen bewusst nicht in der Repo.

## Schiffsansicht

- Der Raumplan ist eine eigene Ebene über einem deutlich größeren Rumpf. Der Rumpf hat Volumen (Aufbauten, Gondeln), die Räume nehmen grob 60 % der Fläche ein.
  → Hullbound: Schiffe etwa 360 × 180 px, Kachel bleibt 14 px.
- Raumgrößen gemischt: 2×2 für Systeme, 1×2 bzw. 2×1 für Gänge und Nebenräume.
  → Hullbound: Systeme 2×2, zusätzlich 1×2-Räume erlauben.
- Waffen hängen sichtbar außen an Hardpoints. Die Schildblase ist ein eigener Effekt um das ganze Schiff.
  → Hullbound: eigene Schildoptik, kein Wabenmuster.
- Türen sind kleine Doppelbalken auf den Wänden.
- Ein Raum unter der Maus oder ein ausgewählter Raum bekommt einen farbigen Rahmen.

## Crew an Bord

- Eine Figur belegt etwa 1 Kachel, bis zu 4 Figuren passen in einen 2×2-Raum. In Hullbound umgesetzt.
- Eine ausgewählte Figur bekommt eine farbige Kontur.
  → Hullbound: Auswahlzustand automatisch aus der Pipeline, mit heller statt dunkler Kontur.
- Über verletzten oder ausgewählten Figuren steht ein Lebensbalken.
  → Hullbound: 1 px hoch über dem Kopf.
- Tooltip auf einer Figur: voller Name, Spezies, Gesundheit, Eigenschaften der Spezies.

## Crew-Liste und Fähigkeiten

- Liste am linken Rand: Mini-Porträt, Name, Lebensbalken, Hotkey.
- Tooltip mit 6 Fähigkeiten und Balken: Steuern, Antrieb, Schilde, Waffen, Reparatur, Kampf. Der stärkste Wert ist hervorgehoben.
  → Hullbound: 6 eigene Fähigkeiten-Icons, 12 px groß.

## Weitere Screens

- **Schiff aufrüsten:** Systeme als Spalten mit Energiebalken und Kosten; Subsysteme; Reaktor-Ausbau.
- **Crew:** Karten mit Porträt, Name und „Entlassen“. Hier kommt das Porträt mit 40 × 44 px zum Einsatz.
- **Ausrüstung:** Waffen, Drohnen, Fracht, Ausbauten, jeweils mit Gegenstandsbild (etwa 48 × 32 px).
- **HUD:** Hülle, Schilde, Treibstoff, Raketen, Drohnenteile, Währung, Energie, Waffenleiste, Sprungknopf.

## HUD oben links (Detail)

- Hüllenbalken aus einzelnen Segmenten (etwa 30), daneben der Zahlenwert der Hülle. Die Farbe wechselt je nach Zustand.
- Darunter die Schilde als runde Ladungen (hier 4), mit einem Ladebalken für die nächste Ladung.
- Zähler mit Symbol und Zahl: Treibstoff, Raketen, Drohnenteile.
- Ausweichen in Prozent und Sauerstoff in Prozent als kleine Balken.
- Die Währung (Schrott) steht als eigener Zähler mit Zahnrad-Symbol. Ein Tooltip erklärt jedes Element („Aktuelle Schrottmenge.“).
- Die Tooltips erklären auch die Regel dahinter. Treibstoff: Jeder Sprung kostet 1 Einheit. Raketen: Manche Waffen verbrauchen pro Schuss 1 Rakete. Drohnenteile: Jeder Drohnen-Einsatz verbraucht 1 Teil.
- Sauerstoff: Prozentwert für das ganze Schiff. Die Lebenserhaltung hält ihn konstant, solange sie Energie hat.
- Ausweichen: Chance in Prozent, dass ein Schuss das Schiff verfehlt. Hängt von der Energie im Antrieb ab.
- Rechts davon der Sprungknopf: wird hervorgehoben, sobald der Sprungantrieb geladen ist.

→ Hullbound: segmentierter Hüllenbalken mit Farbstufen Grün, Orange, Rot aus der Palette. Für Schilde, Treibstoff, Raketen, Drohnenteile, Währung, Ausweichen und Sauerstoff jeweils eigene Symbole (12–16 px), kein Zahnrad für die Währung. Jedes HUD-Element bekommt einen Tooltip.

## Energieleiste unten links

- Senkrechter Balken links für die Reaktorenergie. Gefüllte Segmente sind frei verfügbare Energie.
- Daneben eine Säule pro System: rundes Symbol unten, darüber die Segmente der zugeteilten Energie.
- Über einer Säule zeigt ein kleines Figürchen an, dass der Raum besetzt ist. Sterne darüber stehen für die Fähigkeitsstufe der Person.
- Tooltip auf einem System: Funktion, aktuelle Stufe und was sie bewirkt (z. B. „Stufe 8: Vier Schildbarrieren“), Bonus bei Besetzung (z. B. 30 % schnelleres Laden), Status (z. B. volle Energie) und Tastenkürzel für Energie an und aus.

→ Hullbound: Systemsymbole in einer runden Plakette (etwa 16–24 px), segmentierte Energiesäulen, ein Besetzt-Symbol mit Stufenanzeige. Das Tooltip-Panel muss mehrere Absätze tragen.

## Gesamtlayout des Kampfbildschirms

- Oben links: Hülle, Schilde, Zähler, Ausweichen, Sauerstoff. Darunter die Crew-Liste.
- Oben Mitte: Währung, Sprungknopf mit Ladeanzeige, dazu die Knöpfe Schiff/Upgrade und Optionen.
- Mitte: das eigene Schiff mit Schildblase.
- Unten links: Reaktor und Energiesäulen der Systeme.
- Unten Mitte: Waffenleiste mit Ladebalken je Waffe (z. B. 6.4/6.4) und einem Schalter für Dauerfeuer. Daneben die Drohnenleiste.
- Unten rechts: Subsysteme und ein Lupenknopf für „erweiterte Infos“. Der Schalter blendet zusätzliche Kurzinfos ein: zu Waffen, Drohnen, Ausbauten und Crew, außerdem Kartenverbindungen, Sauerstoff pro Raum und Reaktorenergie im Hangar. Auf dem PC liegt er zusätzlich auf einer Taste.

→ Hullbound (Android): Auf dem Touchscreen gibt es weder Mauszeiger noch Tastenkürzel.
- Tooltips öffnen sich per langem Tippen.
- Erweiterte Infos und Energie an/aus brauchen eigene Knöpfe bzw. Gesten.
- Alle tippbaren Elemente brauchen mindestens 48 dp Trefferfläche. Das ist bei der Größe der Symbole einzuplanen.

## Sektorkarte (Sprungkarte)

- Knoten (Sprungziele) sind durch gestrichelte Linien verbunden. Grün markiert sind die Ziele, die vom aktuellen Standort erreichbar sind.
- Das Schiff steht als kleines Symbol am aktuellen Knoten.
- Bereits besuchte Knoten sehen anders aus als unbesuchte.
- Knoten können ein Label tragen: Ausgang, Notruf, Auftrag.
- Nebelgebiete liegen als farbige Wolken auf der Karte und wirken als Gefahrenzone.
- Fährt man mit der Maus über einen Knoten, werden seine Verbindungen gelb hervorgehoben. Ein Tooltip nennt den Status und, falls bekannt, den Grund, zum Beispiel „Nicht besucht. Ziel eines Auftrags.“
- Manche Knoten tragen einen großen, farbig leuchtenden Ring als Sondermarker.
- Unten stehen Name und Typ des Sektors, dazu „Abbrechen“.
- Der Hintergrund ist eine fotoartige Galaxie.
  → Hullbound: Hintergrund als Pixel-Art in der eigenen Palette, kein Foto.

Für Hullbound gebraucht: Karten-Hintergrund, Knoten-Symbole für die Zustände unbesucht, besucht, aktuell, erreichbar, Ausgang, Notruf, Auftrag und Händler, Verbindungslinien, Nebel-Overlay, Schiffsmarker und Label-Schilder.

## Abgrenzung

- Keine Namen aus dem Vorbild, also kein „FTL-Antrieb“, keine Waffen- oder Spezies-Namen. Stattdessen etwa „Sprungantrieb“.
- Keine Rahmenoptik mit abgeschrägten Kanten, Cyan-Leuchtrand und rosa Feldern.
- Spezies-Eigenschaften selbst entwerfen. Vor allem die Androiden dürfen nicht die Werte der Roboter-Spezies im Vorbild übernehmen (doppelte Reparatur, halber Schaden).
