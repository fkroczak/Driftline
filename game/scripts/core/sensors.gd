class_name Sensors
extends RefCounted
## Was die eigenen Sensoren vom Gegnerschiff zeigen (Stufe = Energie in den Sensoren):
## 0 = nur der Grundriss, 1 = welcher Raum welches System ist, 2 = zusätzlich die Besatzung,
## 3 = zusätzlich die Energie je System.

const ROOMS := 1
const CREW := 2
const POWER := 3


static func shows_rooms(level: int) -> bool:
	return level >= ROOMS


static func shows_crew(level: int) -> bool:
	return level >= CREW


static func shows_power(level: int) -> bool:
	return level >= POWER
