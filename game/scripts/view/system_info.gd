class_name SystemInfo
extends RefCounted
## Namen und Kurzbeschreibungen der Systeme für Legende, Infozeile und Energieleiste.

const ENTRIES := [
	# System-ID, Name, was es tut (kurz, passt in eine Zeile)
	["reaktor", "Reaktor", "liefert Energie (Leiste ganz links)"],  # i18n
	["schilde", "Schilde", "2 Balken (Back- + Steuerbord) = 1 Schicht"],  # i18n
	["waffen", "Waffen", "Energie für die Waffen unten rechts"],  # i18n
	["antrieb", "Antrieb", "Ausweichen und Sprung (Pilot nötig)"],  # i18n
	["cockpit", "Cockpit", "Pilot hier = Ausweichen und Sprung"],  # i18n
	["lebenserhaltung", "Lebenserhaltung", "füllt Sauerstoff in allen Räumen nach"],  # i18n
	["medbay", "Medbay", "heilt Crew, die im Raum steht"],  # i18n
	["sensoren", "Sensoren", "noch ohne Wirkung (später: Gegner sehen)"],  # i18n
	["", "Erweiterung", "freier Platz für spätere Module"],  # i18n
]


static func display_name(system: String) -> String:
	for e in ENTRIES:
		if e[0] == system:
			return Loc.t(e[1])
	return system


static func describe(system: String) -> String:
	for e in ENTRIES:
		if e[0] == system:
			return Loc.t(e[2])
	return ""
