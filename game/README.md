# Hullbound – Godot-Projekt

Prototyp Phase 2 (siehe [GDD](../docs/GDD.md#technik-und-roadmap)): ein ganzer Run durch ein Universum. Phase 1 (macht der Kampf per Touch Spaß?) ist abgeschlossen.

**Stand:** Das Spiel startet auf der Sternenkarte. Der Mensch-Frachter mit drei Crewmitgliedern springt in 10 Sprüngen vom Start zum Boss. Unterwegs warten Kämpfe, Ereignisse mit Textentscheidungen, Händler, eine Reparaturstation oder leere Systeme. Im Kampf links die Crew-Leiste, unten Energie und Waffen, oben rechts Hülle, Schild und Ausweichchance.

### Sternenkarte und Run

- **Karte** (`StarMap`, je Run ein Seed): 11 Spalten von links (Start) nach rechts (Boss = Ausgang), dazwischen je 2–3 Systeme. Ein Sprung führt immer in die nächste Spalte, also braucht jeder Weg genau 10 Sprünge. Verbindungen kreuzen sich nicht, und von jedem System aus ist der Boss erreichbar.
- **Bedienung:** Ein gelbes (erreichbares) Ziel antippen zeigt das Infofeld, nochmal antippen springt. Grün = besucht, weiß = unerforscht, roter Rhombus = Boss. Oben Treibstoff, Rohstoffe, Hülle, Crew und Sprünge.
- **Systeme:** je Karte 2 Händler (Sprung 2–4 und 6–8) und 1 Reparaturstation (Sprung 4–8), immer sichtbar. Der Rest: 45 % Kampf, 42 % Ereignis, 13 % leer. Notrufe (rote Ringe) zeigt die Karte nur bis 2 Sprünge voraus; alles andere bleibt „unerforscht“.
- **Ressourcen** (`data/run.json`): Start mit 6 Treibstoff und 10 Rohstoffen. Jeder Sprung kostet 1 Treibstoff. Ohne Treibstoff erscheint der Knopf **NOTSIGNAL**: Es antwortet ein Händler, Piraten (Kampf um ihre Tanks) oder eine Gildenpatrouille.
- **Beute:** Nach jedem Sieg Rohstoffe und manchmal Treibstoff, je nach Stufe (`reward` in `data/enemies.json`).
- **Ereignisse** (`data/events.json`, Format im Feld `_doc`): Wrack, Rettungskapsel, Eismond-Station, Kolonie in Not, havarierter Gildenfrachter, Asteroidenfeld, Piratenzoll, Schmuggler, Ionensturm, stillgelegte Mine, abgestürzte Fähre, Geleitschutz. Dialog links mit kleiner Szene, rechts Text, darunter die Optionen. Optionen kosten eventuell Rohstoffe oder Treibstoff (grau, wenn es nicht reicht), Außeneinsätze brauchen mindestens 2 Crew. Ausgänge sind gewichtet: Rohstoffe, Treibstoff, Hülle (+/−), verletzte, gefallene oder neue Crew, Ansehen, ein Kampf (mit Extrabeute nach dem Sieg) oder ein Folgeereignis.
- **Ansehen:** „Gildenbrief“ (`gilde_freund`) macht Händler 25 % billiger und öffnet bei der Gildenpatrouille eine eigene (blaue) Option. „Dank der Kolonie“ (`kolonie_dank`) bringt einmal eine Gratis-Komplettreparatur in der Reparaturstation. Manche Ereignisse reparieren aus Dankbarkeit auch sofort die Hülle.
- **Händler:** 1 Treibstoff für 3 Rohstoffe, Hülle +5 für 8 Rohstoffe, Hülle +3 für 1 Treibstoff. **Reparaturstation:** Komplettreparatur (Hülle und Systeme) für 1 Rohstoff je Hüllenpunkt plus 2 je Schaden, nur Systeme und Lecks für 2 je Schaden, Hülle +5 für 5, Hülle +4 für 1 Treibstoff.
- **Bleibender Schaden, kein Automatismus:** Ein einziges Schiff geht durch den ganzen Run, und nach dem Kampf wird nichts von selbst repariert. Nach einem Sieg läuft die Zeit an Bord weiter (Banner „Repariert, was ihr könnt“, Sprungknopf wird zu **KARTE**): Crew in beschädigte Räume schicken, Medbay mit Energie versorgen, dann KARTE antippen. Was offen bleibt, kommt mit: Systemschäden, Lecks, Brände, wenig Luft, verletzte Crew, entladene Schilde. Auch ein Sprung dauert an Bord 8 Sekunden, in denen Brände wachsen und sich ausbreiten. Nach einer Flucht gibt es keine Nachbereitung. Die Karte zeigt offene Schäden unten an.
- **Reparieren:** Systeme repariert die Crew im Raum (im Kampf und danach). Die Hülle nur Händler, Reparaturstation oder Ereignisse. Die Reparaturstation setzt auch Systeme, Lecks und Brände instand (2 Rohstoffe je Schaden).
- **Gegnerstufen** (`data/enemies.json`): ab Sprung 1 nur der Piratenkutter, ab Sprung 4 zu 35 % der Schwere Kutter, ab Sprung 7 zu 65 % und alle mit +2 Hülle. Boss: das Piraten-Flaggschiff (Schwerer Kutter mit 24 Hülle). Der Gegner pro System steht fest (aus Seed und Knoten).
- **Ende:** Niederlage (auch Hülle oder Crew durch ein Ereignis verloren) beendet den Run, Sieg über den Boss schafft das Universum; danach antippen für einen neuen Run. Wer vor dem Boss flieht, steht weiter vor ihm und greift durch Antippen des eigenen Schiffs auf der Karte erneut an.
- **Balance:** Seit Schäden zwischen den Kämpfen bleiben, sind die Simulationen mit dem einfachen Bot (keine Crew-Steuerung) nicht mehr aussagekräftig; die Werte müssen im echten Spiel getestet werden. Stellschrauben sind die Preise in `data/run.json`, die Beute in `data/enemies.json`, die Anteile `TYPE_WEIGHTS` in `scripts/core/star_map.gd` und `JUMP_SHIP_TIME` in `scripts/core/run_state.gd`.

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
- **Tätigkeit sichtbar:** Symbol über dem Kopf und in der Crew-Leiste: Tropfen = löscht (Schaum spritzt zum Feuer), Hammer = flickt Leck, Schraubenschlüssel = repariert (Funken, Figur hämmert), grünes Plus = wird in der Medbay geheilt. Die Crew-Leiste zeigt kompakte Porträts mit Lebens- und Erfahrungsbalken.
- **Lebenspunkte** (100): Balken unter dem Porträt und über verletzten Figuren. Schaden durch Treffer im Raum (15 je Schadenspunkt), Feuer (5/s auf der Kachel, 1,5/s im Raum) und Ersticken (6/s unter 10 % Luft). Die Medbay heilt mit Energie 6/s je Balken. Bei 0 stirbt die Figur.

### Energie und Kampf

- **Pause** (Knopf oben neben „?“, am Desktop auch die Leertaste): Der Kampf steht, alles bleibt bedienbar (Energie, Ziele, Crew, Türen, Schleusen). Antippen setzt fort.
- **Auto-Pause** (am Start an, kleines „A“ am Pauseknopf; gedrückt halten schaltet um): Wer eine Crew-Figur oder Waffenkarte auswählt, hält den Kampf an. Mit dem Befehl oder beim Abwählen läuft er weiter. Eine selbst gesetzte Pause bleibt, bis man fortsetzt.

- **Symbole:** Der „?“-Knopf unten rechts öffnet eine Legende (Kampf pausiert). Eine Energiespalte oder einen eigenen Raum antippen zeigt in der Infozeile, was das System tut.
- **Hülle:** Zahl und Balken, oben rechts für das eigene Schiff, über dem Gegner für ihn. Frisch verlorene Punkte glühen kurz rot. Darunter getrennt die Schildschichten.

- **Energie** (Leiste unten): Spalte antippen = 1 Balken mehr, gedrückt halten oder Rechtsklick = 1 Balken weniger. Ganz links der Reaktor: gelb = frei, rot = zerstört. Bei Systemen: grün = versorgt, rot = beschädigt.
- **Startverteilung** (Reaktor 6, bewusst knapp): Lebenserhaltung 1, Schilde 2, Waffen 3. Antrieb, Sensoren und Medbay bleiben aus, bis du umschichtest, zum Beispiel den Schweren Laser ab, damit der Antrieb Ausweichen bringt oder die Medbay heilt.
- **Waffen** (Karten unten, nummeriert): Mit Energie lädt eine Waffe, ohne entlädt sie sich. Geladen feuert sie selbst auf ihr Ziel; ohne Ziel blinkt die Karte. Gedrückt halten oder Rechtsklick schaltet eine Waffe ein oder aus.
- **Zielen, alle Waffen:** einen Gegnerraum antippen (knapp daneben zählt auch)
- **Zielen, einzeln:** Waffenkarte antippen (rot umrandet), dann einen Gegnerraum. Den aktuellen Zielraum der Waffe erneut antippen hebt das Ziel auf. Fadenkreuze im Gegnerschiff tragen die Waffennummer.
- **Einschlag:** Ausweichen (Antrieb + besetztes Cockpit), sonst fängt der Schild ab (2 Balken = 1 Schicht: Backbord und Steuerbord, in der Energieleiste nebeneinander; ist einer beschädigt oder ohne Energie, fällt die Schicht weg und der übrige Balken leuchtet gelb; eine Schicht lädt in 3 s nach, mit besetzter Konsole schneller), sonst Treffer: Hülle und System im Raum verlieren Balken
- **Reaktortreffer** senken die verfügbare Energie; dann werden Systeme in der Reihenfolge Lebenserhaltung, Schilde, Waffen, Antrieb, Sensoren, Medbay versorgt. Nach der Reparatur kommt die gewünschte Energie von selbst zurück.
- **Gegner** (je nach Sprungnummer, siehe oben): der **Piratenkutter** (Hülle 18, Reaktor 6, eine Schildschicht, Pulslaser und Bordkanone) oder der rötliche **Schwere Kutter** (Hülle 18, Reaktor 8, eine Schildschicht, Pulslaser und zwei Bordkanonen). Name steht über dem Hüllenbalken. Jede Waffe zielt alle paar Sekunden auf einen anderen Raum. Die Mechanikerin oder der Mechaniker löscht Feuer, flickt Lecks, repariert Systeme und kehrt danach zur Konsole zurück. Der Kutter hat keine Lebenserhaltung, aber eine eingebaute Luftaufbereitung (`oxygen_regen`).
- **Balance (Einzelkampf):** In 20 simulierten Kämpfen ohne Eingreifen (Antrieb aus) gewinnt der Frachter gegen den Piratenkutter 17, im Schnitt nach rund 60 s. Gegen den Schweren Kutter gewinnt er passiv 14 von 30, schon mit einer einfachen Taktik (Lebenserhaltung aus, Antrieb an) 17 von 30.
- **Regel: kein No-win-Szenario.** Jeder Gegner muss mit gutem Spiel schlagbar sein; der Sprung ist der Notausgang. Zwei Schildschichten beim Gegner sind mit 6 Reaktorbalken kaum zu knacken (auch Salven helfen nicht: 4 von 30) und bleiben späteren Gegnern vorbehalten, wenn das eigene Schiff ausgebaut werden kann. Zwei Schildschichten beim Gegner waren zu viel (nur 9–12 von 20, Test am Handy: mehrfach verloren).
- **Treffer** können Feuer (30 %) und Hüllenbrüche (10 %) im Raum auslösen.
- **Sauerstoff** je Raum: Die Lebenserhaltung füllt nach (4 %/s je Balken). Feuer verbraucht Luft, Hüllenbrüche und offene Schleusen lassen sie entweichen. Räume mit wenig Luft färben sich rosa; „Luft“ oben rechts ist der Schnitt über alle Räume.
- **Feuer** (je Kachel): breitet sich bei mehr als 25 % Luft aus, im Raum und durch offene Türen; unter 12 % erlischt es. Es beschädigt das System im Raum.
- **Türen** antippen: auf oder zu (am Start alle zu). Offene Türen gleichen die Luft zwischen Räumen aus und lassen Feuer durch. Die eigene Crew läuft auch durch geschlossene Türen.
- **Luftschleusen** antippen (gelbe Luken auf der Außenwand, Frachter 2, Kutter 1): offen saugen sie den Raum in 2 s leer, über offene Türen auch die Nachbarräume. So erstickt man Feuer; eigene Crew sollte den Raum vorher verlassen.
- **Fluchtsprung** (Knopf „SPRUNG“ unten rechts): Der Antrieb lädt den Sprung, solange er Energie hat und jemand im Cockpit sitzt. Ein Balken braucht 40 s, zwei Balken 20 s, ein besetzter Antrieb geht schneller. Lange Triebwerksflammen zeigen den Ladestand. Voll geladen antippen: Das Schiff springt weg, der Kampf endet mit „Entkommen“. Lädt er nicht, steht der Grund auf dem Knopf (Antrieb aus, kein Pilot).
- **Ende:** Hülle auf 0, ganze Crew tot oder Fluchtsprung. Danach antippen: zurück zur Sternenkarte (oder neuer Run nach Niederlage bzw. Boss-Sieg). Läuft die Kampfszene direkt aus dem Editor (F6), gibt es einen Probekampf am ersten System.

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
| `data/enemies.json` | Gegnerstufen je Sprungnummer (gewichtete Schiffe, Hüllenbonus) und der Boss |
| `data/run.json` | Run-Regeln: Startressourcen, Sprungkosten, Preise bei Händler und Reparaturstation, Gildenrabatt |
| `data/events.json` | Ereignisse mit Optionen, Kosten, Bedingungen und gewichteten Ausgängen (Format im Feld `_doc`) |
| `scripts/core/` | Reine Spiellogik ohne Nodes: `ShipLayout` (Raster, Wegfindung), `CrewMember`, `ShipSystem`, `Weapon`, `ShipState` (Energie, Schaden, Reparatur, Schilde), `Battle` (Schüsse, Einschläge, Gegner-KI, Ereignisse), `StarMap` (Sternenkarte), `RunState` (Run: Karte, Position, Schiff, Ressourcen, Dialoge, Händler, Gegnerwahl), `EventBook` (Ereignisse laden, ziehen, prüfen) |
| `scripts/view/` | Darstellung und Eingabe: `ShipView` (eigenes und Gegnerschiff), `Effects`, `PowerPanel`, `WeaponPanel`, `StatusBar`, `CrewPanel`, `MapView` (Sternenkarte), `EventDialog` (Ereignis-, Händler- und Werftdialog) |
| `scripts/game.gd` | Autoload `Game`: hält den Run über Szenenwechsel, wechselt zwischen Karte und Kampf |
| `scenes/map.tscn` | Startszene: Sternenkarte (`scripts/map_screen.gd`) |
| `scenes/battle.tscn` | Kampf (`scripts/battle_screen.gd`) |
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

**Updates:** Jede neue APK installiert sich als Update über die vorige, ohne Deinstallieren. Dafür sorgen zwei Dinge:

- **Fester Schlüssel:** Alle Builds werden mit `tools/android/debug.keystore` signiert (Passwort `android`, Alias `androiddebugkey`). Diesen Schlüssel nicht austauschen, sonst muss jedes Handy einmal deinstallieren. Ein Repository-Secret `ANDROID_DEBUG_KEYSTORE_BASE64` hätte Vorrang. Der Schlüssel ist öffentlich und taugt nur für Testversionen; für den Play Store braucht es später einen eigenen, geheimen Release-Schlüssel.
- **Versionsnummer:** `versionCode` ist die Laufnummer des Workflows und steigt mit jedem Build. Der Versionsname setzt sich aus `config/version` in `project.godot` (z. B. `0.2`) und dieser Nummer zusammen, etwa `0.2.17`. Er steht klein oben rechts auf der Sternenkarte, im Namen der APK und im Release. Für einen neuen Meilenstein nur `config/version` anheben.

Einmalig: Builds vor dieser Umstellung hatten jeweils einen zufälligen Schlüssel. Die alte Version also ein letztes Mal deinstallieren (es gibt noch keine Spielstände, es geht nichts verloren).

Lokal aus dem Editor: Exportvorlagen und Android SDK in Godot einrichten, Handy per USB anschließen, oben rechts auf das Android-Symbol klicken (Remote Debug).
