class_name SystemInfo
extends RefCounted
## Namen und Kurzbeschreibungen der Systeme für Legende, Infozeile und Energieleiste.

const ENTRIES := [
	# System-ID, Name, was es tut (kurz, passt in eine Zeile)
	["reaktor", "Reaktor", "liefert Energie (Leiste ganz links)"],
	["schilde", "Schilde", "je 2 Balken eine Schicht gegen Treffer"],
	["waffen", "Waffen", "Energie für die Waffen unten rechts"],
	["antrieb", "Antrieb", "Ausweichen, nur mit Pilot im Cockpit"],
	["cockpit", "Cockpit", "Pilot hier = Ausweichen möglich"],
	["lebenserhaltung", "Lebenserhaltung", "füllt Sauerstoff in allen Räumen nach"],
	["medbay", "Medbay", "heilt Crew, die im Raum steht"],
	["sensoren", "Sensoren", "noch ohne Wirkung (später: Gegner sehen)"],
	["", "Erweiterung", "freier Platz für spätere Module"],
]


static func display_name(system: String) -> String:
	for e in ENTRIES:
		if e[0] == system:
			return e[1]
	return system


static func describe(system: String) -> String:
	for e in ENTRIES:
		if e[0] == system:
			return e[2]
	return ""
