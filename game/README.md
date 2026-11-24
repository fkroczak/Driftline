# Hullbound – Godot-Projekt

Prototyp Phase 2 (siehe [GDD](../docs/GDD.md#technik-und-roadmap)): ganze Runs in zwei Spielmodi. Phase 1 (macht der Kampf per Touch Spaß?) ist abgeschlossen.

**Stand:** Das Spiel startet im Hauptmenü mit **Spielen** (zwei Modi, **Die Jagd** und **Endloses Universum**, je mit eigenem Spielstand), **Tutorial**, **Lexikon** und **Einstellungen**. Danach ist immer das eigene Schiff zu sehen: in Ruhe, im Kampf, bei Ereignissen und beim Sprung. Die Sternenkarte liegt als Überlagerung darüber.

### Hauptmenü, Tutorial, Lexikon, Einstellungen

- **Hauptmenü:** SPIELEN führt zur Moduswahl (Weiter / Neuer Run, ZURÜCK), dazu TUTORIAL, LEXIKON und EINSTELLUNGEN. Hinter dem Menü zieht der eigene Frachter vorbei.
- **Tutorial:** ein Jagd-Run auf fester Karte, der nie gespeichert wird und keinen Spielstand berührt. Alle Nachbarn des Startsystems sind Kämpfe, der erste Sprung führt also sicher zu einem Piratenkutter. 13 Schritte (Crew wählen und bewegen, Energie, Türen, Pause, Sprung, Karte, Ziel wählen, Kampf gewinnen) in einem Kasten oben; ein blinkender Rahmen zeigt auf das Bedienelement. Aufgaben gehen von selbst weiter, sobald sie erledigt sind, Info-Schritte mit WEITER (das Spiel steht so lange). Jeder Schritt lässt sich überspringen, BEENDEN führt ins Hauptmenü (`scripts/view/tutorial_coach.gd`).
- **Lexikon:** Reiter SCHIFFE und SPEZIES mit Bild, Werten und Beschreibung (`description`/`role` in `data/ships/*.json`, `lore` in `data/species.json`). Freigeschaltet wird über alle Runs hinweg (`user://codex.json`): ein Schiff, sobald man gegen es kämpft, eine Spezies, sobald sie in der eigenen Crew ist. Frachter und Menschen sind von Anfang an bekannt; neue Einträge meldet die Infozeile („Neu im Lexikon: …“). Unbekannte Einträge zeigen nur einen Schatten und einen Hinweis.
- **Einstellungen** (im Menü und im Spiel über den Knopf ≡ oben rechts oder Zurück/Escape, das Spiel steht so lange): Sprache (Deutsch/English), Ton, Schrift HD/Retro, Spieltempo 75/100/125 %, Auto-Pause, Bildschirmwackeln, Vollbild (nur Computer). Gespeichert in `user://settings.json`. Im Spiel zusätzlich WEITERSPIELEN und HAUPTMENÜ (gespeichert wird wie sonst auch nur außerhalb von Kampf und Sprung; im Tutorial: TUTORIAL BEENDEN).

### Mehrsprachigkeit

- **Deutsch und Englisch**, umschaltbar in den Einstellungen (gilt sofort). Beim ersten Start gilt die Systemsprache (Deutsch bei deutschem System, sonst Englisch); gespeichert in `user://settings.json` (`language`).
- **Der deutsche Text ist der Schlüssel:** Im Code steht `Loc.t("Händler")` (`scripts/core/loc.gd`), die Übersetzungen liegen in `i18n/en.json`. Fehlt eine, erscheint der deutsche Text. Formatierte Texte erst übersetzen, dann einsetzen: `Loc.t("Sektor %d") % n`.
- **Spieldaten** (Ereignisse, Spezies, Schiffe, Räume, Waffen) bleiben auf Deutsch in `data/`; angezeigt wird über dieselbe Tabelle.
- **Prüfen:** `python3 tools/i18n_check.py` listet fehlende Übersetzungen, falsche Platzhalter (`%d`, `%s` …) und unbenutzte Einträge. Texte in Konstanten werden mit `# i18n` am Zeilenende markiert, damit das Skript sie findet.
- **Weitere Sprache:** `i18n/<code>.json` anlegen (Vorlage: `python3 tools/i18n_check.py <code> --missing-json`), den Code in `Loc.LANGUAGES` und eine Option in `scripts/view/settings_panel.gd` ergänzen.

### Ablauf: Schiff, Sprung, Ankunft

- **Schiff als Hauptbildschirm:** Auch zwischen den Kämpfen sieht man das Schiff, und die Zeit an Bord läuft weiter. Die Crew löscht, flickt und repariert, die Medbay heilt.
- **Sprungantrieb lädt nach jedem Sprung neu** (Knopf SPRUNG oben rechts mit Ladebalken). **Springen geht nur mit Energie im Antrieb und besetztem Cockpit** (sonst zeigt der Knopf „Antrieb?“ bzw. „Pilot?“). Außerhalb des Kampfs lädt er in 7,5 s mit einem Balken, 5 s mit zwei; im Kampf langsam (Flucht).
- **Springen:** SPRUNG antippen, wenn er voll ist (oder KARTE, um nur zu schauen). Auf der Karte ein gelbes Ziel antippen zeigt das Infofeld, nochmal antippen springt.
- **Sprungeffekt:** Warpblase um das Schiff, das Schiff leuchtet auf und schießt nach rechts davon, die Sterne werden zu Lichtstreifen, ein heller Blitz. Im neuen System gleitet es von links herein, die Blase fällt in sich zusammen. Gegner springen genauso von rechts herein.
- **Am Ziel:** Ereignis, Händler oder Reparaturstation als Dialog über dem Schiff (das Spiel steht so lange), oder der Kampf beginnt.
- **Nach einem Sieg** muss nichts bestätigt werden: Das Banner mit der Beute blendet nach gut 2 s von selbst aus (Antippen schließt es früher), das Schiff ist wieder in Ruhe und der Antrieb lädt.
- **Flucht:** Im Kampf SPRUNG, sobald der Antrieb geladen ist, dann ein Ziel auf der Karte wählen. Der Kampf pausiert, solange die Karte offen ist.
- **Gegner fliehen auch:** Für sie gelten dieselben Regeln (Antrieb mit Energie, Pilot im Cockpit). Fällt die Hülle eines Gegners auf 25 % oder weniger, entscheidet er sich einmal mit 35 % zur Flucht (so flieht etwa jeder dritte, und zwar erst kurz vor der Zerstörung; bis sein Antrieb geladen ist, ist er meist schon kaputt) (`FLEE_HULL`, `FLEE_CHANCE` in `scripts/core/battle.gd`). Dann erscheint ein Hinweis und unter seinem Schiff ein Ladebalken (rot blinkend, solange er lädt; grau, wenn Antrieb oder Pilot fehlen). Ist er geladen, springt der Gegner weg: keine Beute, das System ist danach ruhig. Taktik: Antrieb oder Cockpit treffen, den Piloten ausschalten (die Gegner-Crew schickt dann jemand anderen ins Cockpit) oder ihn vorher zerstören. Boss und Jäger fliehen nie.

### Die Jagd

- **4 Sektoren**, je mit einem Boss am Ausgang (rechts auf der Karte). Nach dem Sieg über den Boss bleibt das Schiff am Ausgang; erst ein eigener Sprung (SPRUNG, sobald der Antrieb geladen ist und jemand im Cockpit sitzt; kostet wie jeder Sprung 1 Treibstoff, ohne Treibstoff hilft das Notsignal) führt in den nächsten Sektor, dann erscheint die neue Karte und die Front beginnt von vorn. Nach dem vierten ist der Run geschafft.
- **Jägerfront:** Sie rückt mit jedem Sprung um 0,1 Kartenbreite von links vor (rote Fläche, gestrichelt die Lage nach dem nächsten Sprung). Nach 10 Sprüngen hat sie den Ausgang erreicht. Einen Sprungzähler gibt es nicht mehr, die Front auf der Karte zeigt die Lage.
- **Springen kann man trotzdem, solange Treibstoff da ist.** Jedes System hinter der Front ist von den Jägern besetzt: Wer dort ankommt (auch zurück in besuchte Systeme), kämpft gegen eine **Jäger-Fregatte** (Hülle 22, Reaktor 9, Pulslaser, Schwerlaser und Bordkanone). Ab Sprung 11 kommen je Sprung 2 Hülle dazu. Händler und Ereignisse hinter der Front sind weg. Der Sieg bringt wenig Beute (4–8 Rohstoffe); die Flucht ist der Notausgang.
- **Vorwarnung:** Das Infofeld auf der Karte zeigt „Jäger in 1/2 Sprüngen hier“.

### Endloses Universum

- Keine Front und kein Boss. Am Ausgang ist der Sektor geschafft; wie in der Jagd führt erst ein eigener Sprung (SPRUNG) in den nächsten Sektor.
- Die Gegner werden mit jedem Sektor stärker (Stufe +3, Hülle +2, Beute +2 Rohstoffe je Sektor, siehe `data/enemies.json`).
- **Rekord:** der erreichte Sektor, im Hauptmenü angezeigt (`user://highscore.json`, auch der beste Sektor der Jagd).

### Sternenkarte

- **Jede Karte ist anders** (`StarMap`, Seed aus Run und Sektor): 20–25 Systeme frei verteilt mit Mindestabstand, Start ganz links, Ausgang ganz rechts. Verbindungen aus Delaunay-Dreiecken: Der Spannbaum hält alles zusammen, lange Kanten fallen weg, und von den übrigen fällt rund ein Drittel zufällig weg. Nichts kreuzt sich, und der kürzeste Weg zum Ausgang braucht 5 bis 8 Sprünge. Verbindungen gelten in beide Richtungen: Man kann zurückspringen (ein besuchtes System löst nichts erneut aus; Händler und Reparaturstation öffnen wieder).
- **Darstellung:** Grün = besucht, gelb = erreichbar (nur mit geladenem Antrieb), weiß = unerforscht, rot = von Jägern besetzt, roter Rhombus = Boss, blauer Ring = Ausgang. Oben Treibstoff (Kanister), Rohstoffe (Zahnrad), Hülle (Rumpf-Symbol) und Sektor, unten rechts ZURÜCK.
- **Systeme:** je Karte 2 Händler (einer in der linken, einer in der rechten Hälfte) und 1 Reparaturstation (Mitte), immer sichtbar. Der Rest: 45 % Kampf, 42 % Ereignis, 13 % leer. Notrufe (rote Ringe) zeigt die Karte nur bis 2 Sprünge weit; alles andere bleibt „unerforscht“.
- **Ressourcen** (`data/run.json`): Start mit 6 Treibstoff und 10 Rohstoffen. Jeder Sprung kostet 1 Treibstoff. Ohne Treibstoff erscheint auf der Karte der Knopf **NOTSIGNAL**: Es antwortet ein Händler, Piraten (Kampf um ihre Tanks) oder eine Gildenpatrouille.
- **Beute:** Nach jedem Sieg Rohstoffe und manchmal Treibstoff, je nach Stufe (`reward` in `data/enemies.json`). Der Boss bringt 20–30 Rohstoffe und 3–4 Treibstoff für den nächsten Sektor. **Alle Rohstoffe aus Beute und Ereignissen zählen 15 % mehr** (`scrap_gain` in `data/run.json`; erst 25 %, das war mit ausgebautem Schiff zu viel, gerundet; die Zahlen in `enemies.json` und `events.json` sind die Grundwerte), damit der Schiffsausbau im Lauf eines Runs erreichbar ist. Preise und Verkäufe ändert der Faktor nicht.
- **Ereignisse** (`data/events.json`, Format im Feld `_doc`): Wrack, Rettungskapsel, Eismond-Station, Kolonie in Not, havarierter Gildenfrachter, Asteroidenfeld, Piratenzoll, Schmuggler, Ionensturm, stillgelegte Mine, abgestürzte Fähre, Geleitschutz. Dialog links mit kleiner Szene, rechts Text, darunter die Optionen. Optionen kosten eventuell Rohstoffe oder Treibstoff (grau, wenn es nicht reicht), Außeneinsätze brauchen mindestens 2 Crew. Ausgänge sind gewichtet: Rohstoffe, Treibstoff, Hülle (+/−), verletzte, gefallene oder neue Crew (zufällige Spezies), Ansehen, ein Kampf (mit Extrabeute nach dem Sieg) oder ein Folgeereignis.
- **Aufträge** (Ereignisse mit dem Effekt `quest`): Vier Auftraggeber liegen im normalen Ereignis-Pool: **Kartografen der Gilde** (verschollene Sonde bergen), **Steckbrief** (Kopfgeld auf Kapitän Rask, Informant kostet 5), **Evakuierung** (Ersatzteile zum Transporter bringen) und **Verschüttete Bergleute** (Sprengladungen aus einem Depot holen). Wer annimmt, bekommt ein Ziel im selben Sektor: ein Ereignis- oder leeres System, möglichst 2–4 Sprünge entfernt, unbesucht und so weit vor der Jägerfront, dass man es rechtzeitig erreicht. Die Karte zeigt es immer mit violettem „!“-Rhombus und der Beschriftung AUFTRAG, das Infofeld nennt den Auftrag. Am Ziel beginnt der Abschluss (Pool `auftrag`, nur über Aufträge erreichbar) mit mehreren Stufen (Folgeereignisse), oft einem Kampf und großer Belohnung: 25–45 Rohstoffe, Treibstoff, neue Crew (Bergleute: ein Ormok), Hülle, Gildenbrief oder eine neue Waffe (Salvenlaser; ohne freien Platz wird sie verkauft). **Spezies-Optionen** (blau, `requires.species`) erscheinen nur, wenn jemand dieser Spezies an Bord ist: Veyari täuschen Drohnen, Ormok fordern Rask zum Zweikampf, Kith'ra kriechen durch Lüftungsschächte, Androiden reparieren im Vakuum, Petrani graben sich durch Geröll. Überrennt die Jägerfront das Ziel oder geht es in den nächsten Sektor, verfällt der Auftrag (Hinweis in der Infozeile).
- **Schwierige Entscheidungen** (Aufträge mit Frist und Zwickmühle, keine Option ist einfach die beste): **Fieberschiff** (Kranke an Bord nehmen mit Ansteckungsgefahr, Medikamente für 12 spenden oder das Wrack ausschlachten; in der Klinik voller Lohn, Verzicht zugunsten der Wartenden oder eine Ärztin anheuern), **Der Überläufer** (an die Gilde ausliefern oder den Handel annehmen; am Lager ihn als Köder opfern, gemeinsam kämpfen oder schnell zugreifen) und **Versiegelte Fracht** (die Empfänger sind Piraten: ohne Lohn übergeben, kämpfen oder öffnen; gestohlene Gildenkanonen für Geld ausliefern, eine behalten oder die Gilde rufen). Auch Evakuierung und Bergleute haben jetzt eine Frist (5 Sprünge).
- **Frist** (`frist` im Abschlussereignis): Das Ziel muss spätestens mit dem so vielten Sprung erreicht sein; die Karte zeigt die übrigen Sprünge („AUFTRAG · 3“, rot beim letzten). Das Ziel liegt immer in Reichweite der Frist, aber Umwege zu Händlern kosten Zeit. Wer zu spät kommt, scheitert, und die Effekte unter `fail` treten ein (Fieber breitet sich aus: Crew verletzt; geplatzte Lieferung: schlechter Ruf).
- **Schlechter Ruf** (`ruf_schlecht`, aus gierigen oder zwielichtigen Entscheidungen): Händler verlangen 15 % mehr (`bad_reputation_markup` in `data/run.json`); mit Gildenbrief bleiben 10 % Rabatt.
- **Ansehen:** „Gildenbrief“ (`gilde_freund`) macht Händler 25 % billiger und öffnet bei der Gildenpatrouille eine eigene (blaue) Option. „Dank der Kolonie“ (`kolonie_dank`) bringt einmal eine Gratis-Komplettreparatur in der Reparaturstation. Manche Ereignisse reparieren aus Dankbarkeit auch sofort die Hülle.
- **Händler:** 1 Treibstoff für 3 Rohstoffe, Hülle +5 für 8 Rohstoffe, Hülle +3 für 1 Treibstoff. Dazu zwei Unterseiten: **Waffen kaufen und verkaufen** (2 Waffen im Angebot; neue Waffen kommen in einen freien Waffenplatz, sonst ins Lager; Verkauf zum halben Preis, die letzte Waffe an Bord bleibt) und **Crew anheuern** (2 Leute mit Spezies und Stärken, 20–30 Rohstoffe je Spezies, höchstens 8 an Bord). Die Waren stehen je Händler fest (aus dem Seed), Gekauftes ist weg. Der Gildenbrief macht auch Waffen und Crew billiger. Bei vielen Optionen werden die Knöpfe im Dialog etwas flacher, damit alles passt. **Reparaturstation:** Komplettreparatur (Hülle und Systeme) für 1 Rohstoff je Hüllenpunkt plus 2 je Schaden, nur Systeme und Lecks für 2 je Schaden, Hülle +5 für 5, Hülle +4 für 1 Treibstoff.
- **Bleibender Schaden, kein Automatismus:** Ein einziges Schiff geht durch den ganzen Run, und nichts wird von selbst repariert. Was die Crew nicht behebt, kommt mit: Systemschäden, Lecks, Brände, wenig Luft, verletzte Crew, entladene Schilde. Auch ein Sprung dauert an Bord 8 Sekunden, in denen Brände wachsen und sich ausbreiten.
- **Reparieren:** Systeme repariert die Crew im Raum (immer, auch zwischen den Kämpfen). Die Hülle nur Händler, Reparaturstation oder Ereignisse. Die Reparaturstation setzt auch Systeme, Lecks und Brände instand (2 Rohstoffe je Schaden).
- **Gegnerstufen** (`data/enemies.json`): Die Stufe hängt an der Lage auf der Karte (0 links bis 10 rechts) plus 3 je Sektor. Vorne nur der Piratenkutter, ab Stufe 4 zu 35 % der Schwere Kutter, ab Stufe 7 zu 65 % und alle mit +2 Hülle. **Tiefer im Universum rüsten die Gegner auf** (Zusatzwaffen bekommen Reaktor und Waffensystem dazu): ab Stufe 10 ein Durchschlaglaser, ab 14 +4 Hülle, ab 18 zusätzlich eine Schildschicht, ab 22 statt des Durchschlaglasers ein Torpedo und +6 Hülle. Boss: das Piraten-Flaggschiff (Schwerer Kutter, 24 Hülle, je Sektor +4), ab Sektor 2 mit Durchschlaglaser, ab 3 mit zweiter Schildschicht, ab 4 zusätzlich mit Torpedo. Die Jäger-Fregatte trägt ab Sektor 2 einen Durchschlaglaser. **Gegner-Crews löschen, flicken und reparieren 10 % langsamer** (`repair_speed` 0.9). Messung (ausgebauter Frachter mit Schwerlaser, Salvenlaser, Brandkanone, Bot zielt nur auf die Schilde, je 30 Kämpfe): Reaktor 12/Schilde 4 gewinnt bei Stufe 10–14 29 von 30 (Ø 13 Hülle verloren), bei Stufe 18–22 20–22 von 30 (Ø 22); mit Reaktor 16/Schilde 6 26–30 von 30 (Ø 8–16). Vorher gewann er überall 28–30 von 30 mit 3–7 Hülle Verlust. Der Gegner pro System steht fest (aus Seed, Sektor und Knoten).
- **Ende:** Niederlage (auch Hülle oder Crew durch ein Ereignis verloren) oder Sieg über den letzten Boss beendet den Run; Antippen führt ins Hauptmenü.
- **Balance:** Die Simulationen mit dem einfachen Bot (keine Crew-Steuerung) sind seit dem bleibenden Schaden nicht mehr aussagekräftig; die Werte müssen im echten Spiel getestet werden. Stellschrauben sind die Preise in `data/run.json`, die Beute und Sektor-Zuschläge in `data/enemies.json`, die Trefferchancen in `data/weapons.json`, `TYPE_WEIGHTS` in `scripts/core/star_map.gd`, `FRONT_START`/`FRONT_STEP` und `JUMP_SHIP_TIME` in `scripts/core/run_state.gd` sowie `PEACE_JUMP_TIME` in `scripts/core/ship_state.gd`.

### Schiffsausbau (Knopf SCHIFF)

- **Jederzeit außerhalb des Kampfs:** Knopf **SCHIFF** oben (links neben SPRUNG). Im Kampf, während eines Sprungs oder bei offenem Dialog ist er grau („Ausbauen geht nur außerhalb des Kampfs“). Solange der Bildschirm offen ist, steht das Spiel; beim Schließen wird gespeichert.
- **Seite SYSTEME:** Reaktor, Schilde, Waffen, Antrieb, Medbay und Lebenserhaltung je um einen Balken ausbauen. Grüne Balken = ausgebaut, dunkle = noch möglich, rot = beschädigt. Der Knopf zeigt „+1“ und den Preis (grün = bezahlbar). Den Namen antippen erklärt das System. Sensoren sind nicht ausbaubar, solange sie nichts tun. Preis des nächsten Balkens = `base` + `step` × bisher gekaufte Balken:

  | System | Start | Max | Preise |
  | --- | --- | --- | --- |
  | Reaktor | 7 | 20 | 10, 13, 16 … (bis 20 zusammen 364) |
  | Schilde | 2 | 8 | 25, 35, 45 … (2 Balken = 1 Schicht) |
  | Waffen | 3 | 6 | 20, 28, 36 |
  | Antrieb | 2 | 5 | 15, 23, 31 |
  | Medbay, Lebenserhaltung | 1 | 3 | 15, 25 |

  Neue Reaktorleistung ist sofort frei, Energie verteilt man selbst. Mehr als 5 Balken (Reaktor: 8) zeigt die Energieleiste enger, ab 13 Reaktorbalken in zwei schmalen Spalten. Der Reaktor reicht jetzt bis 20, damit auch Antrieb, Medbay und Lebenserhaltung neben Schilden und Waffen Energie bekommen.
- **Seite WAFFEN & PERKS**, links: die **Waffenplätze** (Frachter: 3, `weapon_slots` in `data/ships/*.json`) und das **Lager** (2 Plätze). LAGER baut eine Waffe aus, EINBAUEN wieder ein (ausgeschaltet; Energie über die Waffenkarte). Kaufen und verkaufen nur beim Händler. Bei drei Waffen werden die Karten unten schmaler.
- **Rechts die Perks**, je einmal kaufbar:

  | Perk | Wirkung | Preis |
  | --- | --- | --- |
  | Verstärkte Panzerung | Hülle +6 (Maximum und sofort) | 30 |
  | Zielcomputer | Waffen laden 15 % schneller | 35 |
  | Ausweichdüsen | +5 % Ausweichen (mit Pilot und Antrieb) | 30 |
  | Reparaturdrohne | Repariert Systeme ohne Crew (¼ Person) | 40 |
  | Brandschutzanlage | Feuer wächst und breitet sich halb so schnell aus | 25 |
  | Bergungsgreifer | +25 % Rohstoffe nach jedem Sieg | 30 |
  | Treibstoffrecycler | Sprung kostet mit 25 % Chance keinen Treibstoff | 35 |

- **Neue Waffen** (`data/weapons.json`, mit `price`): Salvenlaser (3 Schüsse à 1, 2 Energie, 12 s, 55), Brandkanone (1 Schuss, 60 % Feuer, 1 Energie, 12 s, 35), Schwere Kanone (1 Schuss à 3, 3 Energie, 16 s, 70). Pulslaser 30, Schwerlaser 45, Bordkanone 25. **Schilddurchdringend** (`pierce`, durchschlägt so viele Schichten, ohne sie zu verbrauchen; Einschlag zeigt „DURCHSCHLAG“): Durchschlaglaser (1 Schuss à 2, durchschlägt 1 Schicht, 2 Energie, 13 s, 60) und Torpedo (1 Schuss à 2, ignoriert alle Schilde, 2 Energie, 18 s, 70). Damit kann man auch Waffen oder Antrieb direkt treffen, statt erst die Schilde zu zerschießen.
- **Alles in Daten:** Preise, Grenzen, Perks, Lagerplätze, Verkaufsanteil und Crew-Preise in `data/upgrades.json`; Logik in `RunState` (Abschnitt Schiffsausbau) und `ShipState` (Perks, Waffenplätze), Darstellung in `scripts/view/ship_panel.gd`.

### Spielstand

- **Je Modus ein Slot:** `user://savegame.json` (Jagd) und `user://savegame_endlos.json` (Endlos). Das Hauptmenü zeigt „WEITER · Sektor n, Sprung m“; „NEUER RUN“ überschreibt einen gespeicherten Run erst nach einem zweiten Antippen.
- **Automatisch:** gespeichert nach jedem Sprung, jeder Entscheidung, jedem Kampfende, jedem Sektorwechsel und wenn die App in den Hintergrund geht (außer mitten im Kampf oder Sprung). Wird die App mitten im Kampf beendet, beginnt dieser Kampf neu, mit dem Schiff, wie es vorher war.
- **Run vorbei** (Niederlage oder letzter Boss): Der Spielstand des Modus wird gelöscht, der Rekord bleibt.
- **Updates überschreiben nichts:** Android behält die Daten der App bei einem Update (gleicher Schlüssel, siehe unten). Die Datei trägt eine Formatversion (jetzt 4; Version 3 bringt Perks, Waffenlager und Händlerwaren, Version 4 offene Aufträge, ältere Stände starten damit leer). Ältere Stände werden angehoben: Ein Stand der Version 1 (alte Spaltenkarte) wird zum Jagd-Run in Sektor 1, die Sprünge kommen aus der Spalte, die Front wird daraus berechnet, Verbindungen gelten danach in beide Richtungen, Mara Voss wird Captain. Fehlende Felder bekommen Standardwerte, und was es nicht mehr gibt (Waffe, System, Ereignis), wird übersprungen. Die Karte des laufenden Sektors ist mitgespeichert. Eine unlesbare Datei oder ein Stand aus einem neueren Build wird nie überschrieben, sondern als `savegame-<Zeit>.json` beiseitegelegt. Die vorige Fassung bleibt als `.bak.json` zum Rückfall.
- **Beim Entwickeln:** Wer das Format ändert, erhöht `SaveGame.VERSION` und ergänzt in `_migrate` (`scripts/core/save_game.gd`) einen Schritt. Tests dazu stehen am Ende von `tests/run_tests.gd`.

### Crew

- **Auswählen:** Figur im Schiff (knapp daneben zählt auch) oder Porträt in der Leiste antippen; eine andere Figur antippen wechselt die Auswahl
- **Schicken:** danach eine freie Kachel antippen; die Figur läuft genau dorthin, die Auswahl endet. Zur Bestätigung blinkt der Zielraum kurz grün auf und bleibt grün umrandet, bis die Figur angekommen ist
- **Verdrängen:** auf einer besetzten Kachel gedrückt halten; wer dort steht, weicht auf die nächste freie Kachel aus
- **Schleusen nicht aus Versehen:** Mit ausgewählter Figur ist ein Tipp in einen Raum immer ein Laufbefehl, auch direkt an der Schleuse. Schleusen schaltet man ohne Auswahl. Ein Loslassen zählt nur, wenn auch das Drücken im Schiff war (vorher konnte das Loslassen nach einer Dialog-Option eine Schleuse öffnen).
- **Abwählen:** die ausgewählte Figur erneut antippen oder neben das Schiff tippen
- **Konsolen** (Antrieb, Schilde, Sensoren, Waffen, Cockpit; kleine Leiste an der Kachel, grün = besetzt):
  1. Ist die Konsole frei, setzt sich die erfahrenste Person im Raum hin.
  2. Sitzt dort jemand weniger Erfahrenes, tauschen beide, außer diese Person wurde ausdrücklich an die Konsole geschickt.
  3. An der Konsole steigt die Erfahrung im System (1 Stufe in 2 Minuten, Menschen 25 % schneller, höchstens 5). Die Punkte unter dem Porträt zeigen die Stufe im aktuellen Raum.
  4. Eine besetzte Konsole beschleunigt das System: +10 % plus 5 % je Erfahrungsstufe (Schilde laden, Waffen laden, Ausweichen).
- **Arbeit im Raum** (automatisch, wer im Raum steht): erst Feuer löschen, dann Hüllenbrüche flicken (5 s), dann das System reparieren (1 Balken in 4 s). Mehrere Personen arbeiten schneller. **Wer löscht, flickt oder repariert, lernt dabei** (Fertigkeit Reparatur, 1 Stufe je Minute Arbeit, höchstens 5) und arbeitet je Stufe 10 % schneller (Stufe 5: +50 %, zusätzlich zum Spezieswert). Beschädigte Räume pulsieren rot, der gelbe Balken zeigt den Fortschritt.
- **Tätigkeit sichtbar:** Symbol über dem Kopf und in der Crew-Liste: Tropfen = löscht (Schaum spritzt zum Feuer), Hammer = flickt Leck, Schraubenschlüssel = repariert (Funken, Figur hämmert), grünes Plus = wird in der Medbay geheilt.
- **Crew-Liste** (links, wie im Mockup): Porträt, Vorname und Lebensbalken je Person. Auf schmalen Bildschirmen (unter 440 px Breite, also 16:9) nur Porträts.
- **Captain:** Mara Voss trägt einen goldenen Stern in der Crew-Liste, über dem Kopf im Schiff und auf der Crew-Karte.
- **Crew-Karte:** Solange eine Person ausgewählt ist, zeigt eine Karte direkt neben ihrem Eintrag in der Crew-Liste (Pfeil zeigt darauf, nicht mehr über dem Gegner) Name, Captain, Spezies, Lebenspunkte, die Stärken und Schwächen der Spezies und die Erfahrung in Cockpit, Waffen, Schilden, Antrieb, Sensoren und Reparatur (je bis 5 Punkte). Die Karte nimmt keine Eingaben an; man tippt weiter ins Schiff.
- **Spezies** (`data/species.json`, eigene Namen aus dem GDD, Werte angelehnt an das Genre-Vorbild):

  | Spezies | LP | Tempo | Reparatur | Besonderheit |
  | --- | --- | --- | --- | --- |
  | Mensch | 100 | 100 % | 100 % | lernt an Konsolen 25 % schneller |
  | Kith’ra | 110 | 120 % | 60 % | halber Feuerschaden, schwächer an Konsolen |
  | Androide | 100 | 100 % | 160 % | braucht keine Luft, +15 % an den Schilden, Medbay heilt halb so schnell |
  | Veyari | 70 | 100 % | 100 % | +15 % an Waffen und Sensoren |
  | Ormok | 160 | 80 % | 50 % | schwächer an Konsolen |
  | Petrani | 140 | 50 % | 100 % | feuerfest, braucht keine Luft, heilt nicht in der Medbay |

  Neue Crew aus Ereignissen hat eine zufällige Spezies (Menschen häufiger). **Jede Spezies hat eigene Grafik** (nach `art/pixel/species_pixel.png`): Figur an Bord (`assets/crew/<id>_klein_sheet.png`, 4 Richtungen) und Porträt in der Crew-Liste (`<id>_gross_unten.png`, Ausschnitt um den Kopf nach `face` in `data/species.json`), auch im Lexikon. Kith'ra grün mit sechs Beinen und Fühlern, Androiden weiß mit Kuppel, Visier und blauem Kern, Veyari mit großem hellem Kopf und violettem Gewand, Ormok braun und massig mit Helmplatte und Hauern, Petrani aus Stein mit Kristallen und glühender Rune. Laden über `CrewArt` (`scripts/view/crew_art.gd`), fehlt eine Datei, gilt der Mensch. Gegner-Crew bleibt rötlich getönt. Nahkampf gibt es noch nicht, deshalb fehlt der Wert.
- **Lebenspunkte** (je Spezies, Mensch 100): Balken in der Crew-Liste und über verletzten Figuren. Schaden durch Treffer im Raum (15 je Schadenspunkt), Feuer (5/s auf der Kachel, 1,5/s im Raum) und Ersticken (6/s unter 10 % Luft). Die Medbay heilt mit Energie 6/s je Balken. Bei 0 stirbt die Figur.

### Energie und Kampf

- **Pause** (Knopf oben neben „?“, am Desktop auch die Leertaste): Der Kampf steht, alles bleibt bedienbar (Energie, Ziele, Crew, Türen, Schleusen). Antippen setzt fort.
- **Auto-Pause** (am Start an, kleines „A“ am Pauseknopf; gedrückt halten schaltet um): Wer eine Crew-Figur oder Waffenkarte auswählt, hält den Kampf an. Mit dem Befehl oder beim Abwählen läuft er weiter. Eine selbst gesetzte Pause bleibt, bis man fortsetzt.

- **Bildschirm** (nach dem Mockup `art/pixel/hud_kampf_pixel.png`): oben links Hülle (Rumpf-Symbol und Segmente), Schildschichten (Schild-Symbol und Kreise), Luft und Ausweichen (Pfeil); oben Mitte Treibstoff (Kanister) und Rohstoffe (Zahnrad) als Symbole statt Wörtern (der Sektor steht auf der Sternenkarte); oben rechts SPRUNG (mit Ladebalken), KARTE, Pause und „?“; links die Crew-Liste; unten ENERGIE, WAFFEN und TÜREN, jeweils in blau gerahmten Kästen. Die Infozeile steht über den unteren Kästen.
- **Symbole:** Der „?“-Knopf oben rechts öffnet eine Legende (Kampf pausiert). Eine Energiespalte oder einen eigenen Raum antippen zeigt in der Infozeile, was das System tut.
- **Hülle:** Segmente und Zahl oben links für das eigene Schiff, über dem Gegner für ihn. Frisch verlorene Punkte glühen kurz rot.

- **Energie** (Leiste unten): Spalte antippen = 1 Balken mehr, gedrückt halten oder Rechtsklick = 1 Balken weniger. Ganz links der Reaktor: gelb = frei, rot = zerstört. Bei Systemen: grün = versorgt, rot = beschädigt.
- **Startverteilung** (Reaktor 7, knapp): Lebenserhaltung 1, Schilde 2, Waffen 3, Antrieb 1 (ohne Energie im Antrieb kein Sprung). Sensoren und Medbay bleiben aus, bis du umschichtest.
- **Waffen** (Karten unten, nummeriert): Mit Energie lädt eine Waffe, ohne entlädt sie sich. Geladen feuert sie selbst auf ihr Ziel; ohne Ziel blinkt die Karte. Gedrückt halten oder Rechtsklick schaltet eine Waffe ein oder aus.
- **Zielen, alle Waffen:** einen Gegnerraum antippen (knapp daneben zählt auch)
- **Zielen, einzeln:** Waffenkarte antippen (rot umrandet), dann einen Gegnerraum. Den aktuellen Zielraum der Waffe erneut antippen hebt das Ziel auf. Fadenkreuze im Gegnerschiff tragen die Waffennummer.
- **Einschlag:** Ausweichen (Antrieb + besetztes Cockpit), sonst fängt der Schild ab (2 Balken = 1 Schicht: Backbord und Steuerbord, in der Energieleiste nebeneinander; ist einer beschädigt oder ohne Energie, fällt die Schicht weg und der übrige Balken leuchtet gelb; eine Schicht lädt beim Frachter in 2,6 s nach, bei Gegnern in 3 s, mit besetzter Konsole schneller; `shield_recharge` im Schiffs-JSON), sonst Treffer: Die Hülle verliert immer Punkte, das System im Raum nur mit der **Systemchance der Waffe**. Dann blitzt der Raum und „SYSTEM“ erscheint.
- **Trefferchancen je Waffe** (`data/weapons.json`: `system`, `fire`, `breach`):

  | Waffe | System beschädigt | Feuer | Hüllenbruch |
  | --- | --- | --- | --- |
  | Pulslaser (2 Schüsse à 1) | 30 % | 10 % | 5 % |
  | Bordkanone (1 Schuss à 1) | 40 % | 15 % | 10 % |
  | Schwerlaser (1 Schuss à 2) | 70 % | 30 % | 15 % |

  Vorher kostete jeder Treffer einen Systembalken, und 30 % aller Treffer setzten Feuer; deshalb fielen Räume so schnell aus.
- **Reaktortreffer** senken die verfügbare Energie; dann werden Systeme in der Reihenfolge Lebenserhaltung, Schilde, Waffen, Antrieb, Sensoren, Medbay versorgt. Nach der Reparatur kommt die gewünschte Energie von selbst zurück.
- **Gegner** (je nach Stufe, siehe oben): der **Piratenkutter** (Hülle 18, Reaktor 6, eine Schildschicht, Pulslaser und Bordkanone) oder der rötliche **Schwere Kutter** (Hülle 18, Reaktor 8, eine Schildschicht, Pulslaser und zwei Bordkanonen). Name steht über dem Hüllenbalken. Jede Waffe zielt alle paar Sekunden auf einen anderen Raum. Die Mechanikerin oder der Mechaniker löscht Feuer, flickt Lecks, repariert Systeme und kehrt danach zur Konsole zurück. Der Kutter hat keine Lebenserhaltung, aber eine eingebaute Luftaufbereitung (`oxygen_regen`). Hinter der Jägerfront wartet die rote **Jäger-Fregatte** (siehe „Die Jagd“).
- **Balance (Einzelkampf):** In 20 simulierten Kämpfen ohne Eingreifen (Antrieb aus) gewinnt der Frachter gegen den Piratenkutter 17, im Schnitt nach rund 60 s. Gegen den Schweren Kutter gewinnt er passiv 14 von 30, schon mit einer einfachen Taktik (Lebenserhaltung aus, Antrieb an) 17 von 30.
- **Schilde (Messung, Spielerwaffen aus, je 20 Kämpfe à 120 s):** Mit einer Schicht kommen 55 % (Piratenkutter), 67 % (Schwerer Kutter) und 58 % (Jäger) der Gegnerschüsse durch, weil die zweite Kugel einer Pulslaser-Salve immer trifft. Auch mit zwei Schichten (4 Balken) sind es noch 26 %, 44 % und 40 %: Ausgebaute Schilde halten also nicht alles ab. Deshalb lädt der Frachter seine Schilde jetzt in 2,6 s statt 3 s; das senkt die Trefferquote mit einer Schicht um rund 5 Prozentpunkte (Kutter 55 → 49 %), mit zwei um rund 6 (26 → 20 %). Eine nur 5 % kürzere Ladezeit (2,85 s) hätte kaum etwas bewirkt (1 Punkt).
- **Regel: kein No-win-Szenario.** Jeder Gegner muss mit gutem Spiel schlagbar sein; der Sprung ist der Notausgang. Zwei Schildschichten beim Gegner sind mit 6 Reaktorbalken kaum zu knacken (auch Salven helfen nicht: 4 von 30) und bleiben späteren Gegnern vorbehalten, wenn das eigene Schiff ausgebaut werden kann. Zwei Schildschichten beim Gegner waren zu viel (nur 9–12 von 20, Test am Handy: mehrfach verloren).
- **Sauerstoff** je Raum: Die Lebenserhaltung füllt nach (4 %/s je Balken). Feuer verbraucht Luft, Hüllenbrüche und offene Schleusen lassen sie entweichen. Räume mit wenig Luft färben sich rosa; „Luft“ oben rechts ist der Schnitt über alle Räume.
- **Feuer** (je Kachel): breitet sich bei mehr als 25 % Luft aus, im Raum und durch offene Türen; unter 12 % erlischt es. Es beschädigt das System im Raum.
- **Türen** antippen: auf oder zu (am Start alle zu). Offene Türen gleichen die Luft zwischen Räumen aus und lassen Feuer durch. Die eigene Crew läuft auch durch geschlossene Türen. Unten rechts im Kasten TÜREN: „ALLE AUF“ bzw. „ALLE ZU“ schaltet alle Türen, „SCHLEUSE“ (rot, wenn eine offen ist) schließt alle Luftschleusen.
- **Luftschleusen** antippen (gelbe Luken auf der Außenwand, Frachter 2, Kutter 1): offen saugen sie den Raum in 2 s leer, über offene Türen auch die Nachbarräume. So erstickt man Feuer; eigene Crew sollte den Raum vorher verlassen.
- **Fluchtsprung** (Knopf „SPRUNG“ oben rechts): Im Kampf lädt der Antrieb, solange er Energie hat und jemand im Cockpit sitzt. Ein Balken braucht 40 s, zwei Balken 20 s, ein besetzter Antrieb geht schneller. Lange Triebwerksflammen zeigen den Ladestand. Voll geladen antippen öffnet die Karte, ein Ziel zweimal antippen: Das Schiff springt weg. Lädt er nicht, steht der Grund auf dem Knopf (Antrieb?, Pilot?).
- **Ende:** Hülle auf 0, ganze Crew tot oder Fluchtsprung. Nach einem Sieg geht es ohne Antippen weiter (siehe oben), nach dem Run-Ende führt Antippen ins Hauptmenü. Läuft die Schiffsszene direkt aus dem Editor (F6), lädt sie den Jagd-Spielstand oder beginnt einen neuen Run.

### Effekte

Warpblase, Lichtstreifen und Blitz beim Sprung (Abflug und Ankunft, auch bei Gegnern), flackernde Flammen mit Rauch, entweichende Luft an Lecks und offenen Schleusen, Dampf beim Löschen, Geschosse mit Mündungsfeuer, Schildblase mit Welle beim Abfangen, Explosion mit Funken und Rauch, Raumblitz, Bildschirmwackeln und roter Blitz bei eigenen Treffern, schwebende Texte (Schaden, „SCHILD“, „AUSGEWICHEN“, „REPARIERT“), Triebwerksflammen je nach Antriebsenergie, Explosionskette beim Zerstören. Alles ist in `scripts/view/` gezeichnet, ohne zusätzliche Grafikdateien.

### Sound

48 Soundeffekte für alle Situationen, prozedural erzeugt (`tools/sfxgen`, siehe unten), abgespielt vom Autoload `Sfx` (`scripts/sfx.gd`):

- **Waffen:** eigener Klang je Waffe (Pulslaser, Schwerlaser, Bordkanone); Gegnerschüsse tiefer und leiser. Ziel erfasst, Waffe geladen, Waffe angewählt.
- **Einschläge:** Explosion auf der Hülle (lauter je Schaden), Funken bei Systemschaden, Schild, Vorbeiflug, Schiff zerstört. Am Gegnerschiff alles etwas leiser.
- **An Bord:** Feuer bricht aus, Prasseln als Schleife (lauter je mehr Brände), Löschen, Hüllenbruch, Flicken, Reparatur, Crew gefallen, Türen und Schleusen, Schiffsbrummen als Dauerklang.
- **Warnungen:** Alarm, wenn der Gegner fliehen will oder die Jäger kommen; Warnton bei kritischer Hülle (≤ 30 %, höchstens alle 6 s).
- **Sprung und Karte:** Abflug, Ankunft (auch Gegner), Antrieb geladen, Karte öffnen/schließen, Ziel wählen, Flug auf der Karte, Notsignal (SOS).
- **Bedienung:** Knopf, „geht nicht“, Energie ±1, Crew wählen und schicken, Pause/Weiter, Funkspruch bei Ereignissen, Antwort gewählt.
- **Ergebnisse:** Sieg, Beute, Sektor geschafft, Niederlage, alle Sektoren geschafft.

Ton aus/an: Zeile „Ton“ in den Einstellungen (`user://settings.json`, Schlüssel `muted`, über `Settings`). Derselbe Effekt spielt höchstens alle 45 ms, damit Salven nicht übersteuern.

## Öffnen und starten

1. [Godot 4.7](https://godotengine.org/download) installieren (Standard-Version, nicht .NET)
2. In Godot „Importieren“ → `game/project.godot` wählen
3. F5 startet das Spiel

## Aufbau

Logik und Darstellung sind getrennt, damit Spielregeln testbar bleiben und Eingabe (Touch, Maus, Controller) austauschbar ist.

| Pfad | Inhalt |
| --- | --- |
| `data/ships/*.json` | Schiffe: Raster, Räume, Türen als Kachelpaare; Hülle, Reaktor, Systemstufen, Startenergie, Waffen, Grafikpunkte (Waffenmündung, Triebwerke, Schildblase) |
| `data/weapons.json` | Waffenwerte: Energie, Ladezeit, Schüsse, Schaden, Chancen für Systemschaden, Feuer und Hüllenbruch |
| `data/enemies.json` | Gegnerstufen nach Fortschritt (gewichtete Schiffe, Hüllenbonus, Beute), Zuschläge je Sektor, Jäger und Boss |
| `data/species.json` | Spezies: Lebenspunkte, Tempo, Reparatur, Konsolenboni, Feuer, Luft, Medbay, Texte, Namen |
| `data/run.json` | Run-Regeln: Startressourcen, Sprungkosten, Preise bei Händler und Reparaturstation, Gildenrabatt |
| `data/upgrades.json` | Schiffsausbau: Systemstufen und Preise, Perks, Waffenlager, Verkaufsanteil, Waffen- und Crew-Angebot beim Händler |
| `data/events.json` | Ereignisse mit Optionen, Kosten, Bedingungen und gewichteten Ausgängen (Format im Feld `_doc`) |
| `scripts/core/` | Reine Spiellogik ohne Nodes: `ShipLayout` (Raster, Wegfindung), `CrewMember`, `Species`, `ShipSystem`, `Weapon`, `ShipState` (Energie, Schaden, Reparatur, Schilde), `Battle` (Schüsse, Einschläge, Gegner-KI, Ereignisse), `StarMap` (Sternenkarte eines Sektors), `RunState` (Run: Modus, Sektor, Jägerfront, Karte, Position, Schiff, Ressourcen, Dialoge, Händler, Gegnerwahl), `EventBook` (Ereignisse laden, ziehen, prüfen), `Upgrades` (Regeln aus `data/upgrades.json`) |
| `scripts/core/settings.gd`, `scripts/core/codex.gd` | `Settings` (Einstellungen laden, speichern, anwenden) und `Codex` (entdeckte Schiffe und Spezies) |
| `scripts/view/` | Darstellung und Eingabe: `SettingsPanel`, `CodexView` (Lexikon), `TutorialCoach`, `ShipView` (eigenes und Gegnerschiff), `Effects` (auch Warpblase), `Starfield` (mit Lichtstreifen), `HudStyle` und `HudButton` (Kasten-Look), `StatusBar`, `ResourceBar`, `JumpButton`, `PowerPanel`, `WeaponPanel`, `DoorPanel`, `CrewPanel`, `CrewCard`, `MapView` (Sternenkarte als Überlagerung), `EventDialog` (Ereignis-, Händler- und Werftdialog), `ShipPanel` (Schiffsausbau) |
| `scripts/core/save_game.gd` | `SaveGame`: Spielstand speichern und laden, Formatversion und Migration |
| `scripts/sfx.gd` | Autoload `Sfx`: Effekte abspielen (16 Stimmen, Tonhöhe leicht variiert), Schleifen mit Pegel, Ton aus/an |
| `assets/sfx/` | Soundeffekte (WAV, erzeugt mit `tools/sfxgen`) |
| `scripts/game.gd` | Autoload `Game`: hält den Run, wechselt zwischen Hauptmenü und Schiff, speichert je Modus, führt die Rekorde |
| `scenes/title.tscn` | Startszene: Hauptmenü, Moduswahl, Lexikon und Einstellungen (`scripts/title_screen.gd`) |
| `scenes/ship.tscn` | Schiff: Ruhe, Kampf, Ereignisse, Karte und Sprung (`scripts/ship_screen.gd`) |
| `assets/` | Kopien aus `art/export/1x`; `assets/fonts/`: Schrift „Hullbound VT“ = VT323 (SIL Open Font License, `OFL.txt`), um 25 % vergrößert (unitsPerEm 1000 → 800, damit sie bei den bisherigen Schriftgrößen gleich groß wirkt), und `hud_font.tres` |
| `tests/run_tests.gd` | Logiktests |

**Grafik aktualisieren:** Nach `python3 tools/artgen/build.py` die benötigten PNGs aus `art/export/1x/` nach `game/assets/` kopieren. Nur die Crew der Spezies (ohne Mensch, Schiffe, Palette): `python3 tools/artgen/build.py spezies`, dann `<id>_klein_sheet.png` und `<id>_gross_unten.png` kopieren.

**Sounds aktualisieren:** `python3 tools/sfxgen/build.py` schreibt alle Effekte nach `game/assets/sfx/` (nur numpy nötig). Einzelne Effekte: Namen anhängen, z. B. `… build.py laser_pulse`. Mit `--preview ORDNER` landen zusätzlich alle Varianten (A, B, C) zum Vergleichen dort. Welche Variante ins Spiel kommt, steht in `CHOICE` in `tools/sfxgen/sounds.py`.

## Tests

```sh
godot --headless --path game --import                       # einmalig nach dem Klonen
godot --headless --path game --script res://tests/run_tests.gd
```

## Darstellung

Basisauflösung 384 × 216, ganzzahlig hochskaliert (1080p: 5×), Breite passt sich dem Seitenverhältnis an, Querformat, Pixel-Art ohne Filter. Typische Handys (20:9) zeigen 480 × 216; das Desktop-Fenster ist deshalb 1920 × 864 groß. Bei 16:9 (384 px) rücken die Schiffe eng zusammen. Renderer „Compatibility“ für ältere Android-Geräte.

**Schrift:** Pixel-Schrift VT323 (als „Hullbound VT“, klare Buchstabenformen, „la“ und „b“ sind gut zu unterscheiden) als Projektschrift (`gui/theme/custom_font`), Streckmodus `canvas_items`: Spielkoordinaten bleiben 384 × 216, die Schrift wird aber in voller Bildschirmauflösung gezeichnet, ein Schrift-Pixel ist also feiner als ein Spiel-Pixel und gut lesbar. Die Pixel-Art bleibt ganzzahlig skaliert und ungefiltert. In den Einstellungen schaltet „Retro“ zurück auf den Modus `viewport` (alles im groben 384er-Raster).

Ein Raum ist bei 5× auf einem 1080p-Handy 140 px groß (ca. 56 dp, GDD: mindestens 48 dp), eine Kachel 70 px. Hintergrund: Sternenfeld in drei Ebenen (`scripts/view/starfield.gd`).

## Release (Android + iOS)

Gebaut wird nur auf ausdrücklichen Wunsch, nicht bei jedem Push oder Merge (Workflow `.github/workflows/android-apk.yml`). Jedes Release baut immer beide Apps; veröffentlicht wird nur, wenn beide geklappt haben:

- **Tag pushen** (geht von jedem Branch): `git tag release-0.3 && git push origin release-0.3` (alte `apk-…`-Tags gehen auch)
- **Knopf auf GitHub:** Actions → „Release bauen (Android + iOS)“ → „Run workflow“.

Nach etwa 10 Minuten liegen APK und IPA unter **Releases** als Vorabversion.

Der iOS-Teil ist derselbe Ablauf wie `ios-ipa.yml` (wird aufgerufen, nur ohne eigenes Release); Details und Installation siehe **iOS-IPA** unten. Der Workflow-Dateiname `android-apk.yml` bleibt, weil GitHub die Laufnummer (= Android-`versionCode`) je Datei zählt.

## Android-APK

**Updates:** Jede neue APK installiert sich als Update über die vorige, ohne Deinstallieren. Dafür sorgen zwei Dinge:

- **Fester Schlüssel:** Alle Builds werden mit `tools/android/debug.keystore` signiert (Passwort `android`, Alias `androiddebugkey`). Diesen Schlüssel nicht austauschen, sonst muss jedes Handy einmal deinstallieren. Ein Repository-Secret `ANDROID_DEBUG_KEYSTORE_BASE64` hätte Vorrang. Der Schlüssel ist öffentlich und taugt nur für Testversionen; für den Play Store braucht es später einen eigenen, geheimen Release-Schlüssel.
- **Versionsnummer:** `versionCode` ist die Laufnummer des Workflows und steigt mit jedem Build. Der Versionsname setzt sich aus `config/version` in `project.godot` (z. B. `0.2`) und dieser Nummer zusammen, etwa `0.2.17`. Er steht klein oben rechts auf der Sternenkarte, im Namen der APK und im Release. Für einen neuen Meilenstein nur `config/version` anheben.

Einmalig: Builds vor dieser Umstellung hatten jeweils einen zufälligen Schlüssel. Die alte Version also ein letztes Mal deinstallieren (es gibt noch keine Spielstände, es geht nichts verloren).

Lokal aus dem Editor: Exportvorlagen und Android SDK in Godot einrichten, Handy per USB anschließen, oben rechts auf das Android-Symbol klicken (Remote Debug).

## iOS-IPA

Wird bei jedem Release (siehe oben) mitgebaut, auf einem macOS-Runner mit Xcode (Workflow `.github/workflows/ios-ipa.yml`, Preset „iOS“ in `export_presets.cfg`). Nur die IPA allein:

- **Tag pushen** (geht von jedem Branch): `git tag ipa-0.3 && git push origin ipa-0.3`
- **Knopf auf GitHub:** Actions → „iOS-IPA bauen“ → „Run workflow“.

Godot exportiert ein Xcode-Projekt, `xcodebuild` baut daraus die App **ohne Signatur**, und die IPA landet als Vorabversion unter **Releases**. Versionsname wie bei Android (`config/version` plus Laufnummer), Bundle-ID `io.hullbound.prototype`, läuft auf iPhone und iPad ab iOS 14 im Querformat.

**Aufs iPhone:** Apple installiert nur signierte Apps. Ohne Entwicklerkonto geht das per Sideloading mit der eigenen Apple-ID:

- **Sideloadly** (Mac/Windows, iPhone per USB) oder **AltStore/SideStore**: IPA auswählen, mit Apple-ID anmelden, installieren.
- Auf dem iPhone einmalig *Einstellungen → Allgemein → VPN und Geräteverwaltung* dem Entwicklerzertifikat vertrauen; ab iOS 16 außerdem *Datenschutz & Sicherheit → Entwicklermodus* einschalten.
- Mit einer kostenlosen Apple-ID läuft die App 7 Tage, dann neu signieren (AltStore/SideStore erledigt das automatisch). Mit dem Apple Developer Program (99 €/Jahr) 1 Jahr, und TestFlight wird möglich.
- **Updates:** Neue IPA mit derselben Bundle-ID drüberinstallieren, der Spielstand (`user://`) bleibt.

**Bekannt:** Auf iPhones mit Notch oder Dynamic Island kann der Rand der HUD-Leisten im Querformat knapp unter der Aussparung liegen; die sichere Zone (`DisplayServer.get_display_safe_area()`) wird noch nicht berücksichtigt.
