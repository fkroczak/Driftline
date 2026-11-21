class_name ShipSystem
extends RefCounted
## Ein System an Bord (Schilde, Waffen, Antrieb …): Stufen, Energie und Schaden.
##
## capacity: ausgebaute Stufen (Balken). damage: zerstörte Balken.
## wanted: so viel Energie möchte der Spieler hier haben; power: so viel bekommt das System
## gerade wirklich (begrenzt durch Schaden und freie Reaktorleistung, siehe ShipState).

## Systeme ohne eigene Energie: Sie laufen, solange sie nicht ganz zerstört sind.
const PASSIVE := ["cockpit", "reaktor"]
## Sekunden, die eine Person für einen Balken Reparatur braucht.
const REPAIR_TIME := 4.0

var id: String
var capacity := 0
var damage := 0
var wanted := 0
var power := 0
## Fortschritt der laufenden Reparatur (0..1).
var repair_progress := 0.0


func _init(p_id: String, p_capacity: int) -> void:
	id = p_id
	capacity = p_capacity


## Nicht zerstörte Balken.
func usable() -> int:
	return capacity - damage


func is_passive() -> bool:
	return PASSIVE.has(id)


## Wirksame Stufe: Energie bei normalen Systemen, heile Balken bei passiven.
func level() -> int:
	return usable() if is_passive() else power


func apply_damage(amount: int) -> int:
	var dealt := mini(amount, usable())
	damage += dealt
	return dealt


## Reparatur durch `workers` Personen; true, wenn ein Balken fertig wurde.
func repair(delta: float, workers: float) -> bool:
	if damage <= 0 or workers <= 0.0:
		repair_progress = 0.0
		return false
	repair_progress += delta * workers / REPAIR_TIME
	if repair_progress < 1.0:
		return false
	repair_progress = 0.0
	damage -= 1
	return true
