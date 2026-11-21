class_name RunState
extends RefCounted
## Ein Run durch ein Universum: Sternenkarte, Position, eigenes Schiff, Treibstoff und Rohstoffe,
## offene Dialoge (Ereignis, Händler, Reparaturstation). Reine Logik, keine Nodes.
##
## Das Schiff ist ein einziger ShipState, der von Kampf zu Kampf weitergereicht wird.
## Nichts wird automatisch repariert (siehe ShipState.end_combat): Hülle, Systemschäden, Lecks,
## Feuer und verletzte Crew bleiben. Während eines Sprungs vergehen JUMP_SHIP_TIME Sekunden an Bord:
## Brände breiten sich aus, Lecks saugen Luft ab. Systeme repariert die Crew im Kampf oder in der Zeit nach
## einem Sieg; die Hülle nur Händler, Reparaturstation oder Ereignisse. Die Reparaturstation
## setzt auch Systeme und Lecks instand.
##
## Ressourcen: Jeder Sprung kostet Treibstoff. Ohne Treibstoff bleibt nur das Notsignal: Es löst
## ein Ereignis aus dem Pool "notsignal" aus (Händler, Piraten, Gildenpatrouille).
## Rohstoffe gibt es als Beute nach Kämpfen und aus Ereignissen; sie bezahlen Händler und Reparaturen.
##
## Ansehen: Ereignisse setzen Merker (`flags`), z. B. "gilde_freund" (Händler billiger) oder
## "kolonie_dank" (eine Komplettreparatur in der Reparaturstation gratis).
##
## Dialoge: `dialog` ist leer oder {title, text, scene, choices: [{text, enabled, special}]}.
## Die Darstellung zeigt ihn an und ruft `choose(index)` auf. Solange ein Dialog offen ist,
## kann nicht gesprungen werden.

const PLAYER_SHIP := "res://data/ships/mensch_frachter.json"
const ENEMIES_PATH := "res://data/enemies.json"
const RUN_PATH := "res://data/run.json"
const SHIPS_DIR := "res://data/ships/%s.json"
const MAX_CREW := 8
## Schiffszeit während eines Sprungs: Feuer breitet sich aus, Lecks lassen Luft entweichen,
## Crew arbeitet nur dort, wo sie gerade steht.
const JUMP_SHIP_TIME := 8.0
const CREW_NAMES := ["Tess Okafor", "Ruben Lind", "Nia Sato", "Pavel Dorn", "Elin Marsh", "Kofi Brandt",
	"Lena Vasquez", "Ivo Kern", "Suri Haldane", "Mats Ober"]

var seed_value := 0
var map: StarMap
var ship: ShipState
var events: EventBook
## Aktueller Knoten (ID in map.nodes).
var current := 0
## Besuchte Knoten -> true.
var visited: Dictionary = {}
## Knoten, deren Kampf vorbei ist (gewonnen oder entkommen) -> Ergebnis.
var cleared: Dictionary = {}
## Kämpfe, die ein Ereignis ausgelöst hat: Knoten -> Effekte nach dem Sieg.
var pending_battle: Dictionary = {}
## Ereignis je Ereignis-Knoten (beim Start festgelegt, damit die Karte Notrufe zeigen kann).
var node_events: Dictionary = {}
var fuel := 0
var scrap := 0
var flags: Dictionary = {}
## "" solange der Run läuft, sonst "geschafft" (Boss besiegt) oder "verloren".
var result := ""
var dialog: Dictionary = {}
## Beute des letzten Kampfs als Text (für das Banner).
var last_reward := ""

var rules: Dictionary = {}
var _enemy_table: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Was der offene Dialog ist: {kind: "event"|"result"|"shop"|"repair", ...}
var _ctx: Dictionary = {}
var _shop_note := ""


func _init(p_seed := 0) -> void:
	seed_value = p_seed if p_seed != 0 else randi()
	_rng.seed = seed_value
	map = StarMap.generate(seed_value)
	current = map.start_id()
	visited[current] = true
	ship = create_player_ship()
	events = EventBook.load_default()
	_enemy_table = _load_json(ENEMIES_PATH)
	rules = _load_json(RUN_PATH)
	fuel = int(rules.get("start_fuel", 6))
	scrap = int(rules.get("start_scrap", 10))
	var used := {}
	for n in map.nodes:
		if n.type == "ereignis":
			var id := events.pick("ereignis", _rng, used)
			node_events[n.id] = id
			used[id] = true


static func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func create_player_ship() -> ShipState:
	var layout := ShipLayout.load_json(PLAYER_SHIP)
	for error in layout.validate():
		push_error("%s: %s" % [PLAYER_SHIP, error])
	var s := ShipState.new(layout)
	s.add_crew("Mara Voss", "mensch", Vector2i(9, 3), {"cockpit": 3.0, "waffen": 1.0})
	s.add_crew("Jonas Reil", "mensch", Vector2i(6, 6), {"waffen": 3.0, "schilde": 1.0})
	s.add_crew("Ilka Brandt", "mensch", Vector2i(6, 0), {"schilde": 2.0, "antrieb": 2.0})
	return s


func node() -> Dictionary:
	return map.node(current)


## Bisher gesprungen (= Spalte des aktuellen Knotens).
func jumps_done() -> int:
	return node().column


func jump_cost() -> int:
	return int(rules.get("jump_cost", 1))


## Ein Notruf-Ereignis wartet an diesem Knoten (auf der Karte sichtbar).
func is_beacon(id: int) -> bool:
	return node_events.has(id) and events.get_event(node_events[id]).get("beacon", false)


func can_jump_to(id: int) -> bool:
	return result == "" and dialog.is_empty() and not needs_battle() and fuel >= jump_cost() and node().links.has(id)


## Springt zum Knoten. Die Crew bringt das Schiff unterwegs in Ordnung. Am Ziel öffnet sich
## je nach Typ ein Dialog (Ereignis, Händler, Reparaturstation).
func jump_to(id: int) -> bool:
	if not can_jump_to(id):
		return false
	fuel -= jump_cost()
	ship.end_combat()
	_pass_ship_time(JUMP_SHIP_TIME)
	current = id
	visited[id] = true
	_open_node_dialog()
	return true


## Lässt an Bord Zeit vergehen (ohne Kampf). Wer dabei stirbt, ist tot; ohne Crew ist der Run verloren.
func _pass_ship_time(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		ship.update(0.1)
		t += 0.1
	ship.events.clear()
	if ship.is_crew_dead():
		result = "verloren"


func _open_node_dialog() -> void:
	match node().type:
		"ereignis":
			_open_event(node_events.get(current, ""))
		"haendler":
			_shop_note = ""
			_open_shop()
		"reparatur":
			_shop_note = ""
			_open_repair()


## Ohne Treibstoff festsitzen: Notsignal senden.
func can_send_distress() -> bool:
	return result == "" and dialog.is_empty() and not needs_battle() and fuel < jump_cost() and node().type != "boss"


func send_distress() -> bool:
	if not can_send_distress():
		return false
	_open_event(events.pick("notsignal", _rng))
	return true


## Am aktuellen Knoten wartet ein Gegner, der noch nicht besiegt oder abgehängt ist.
## Wer vor dem Boss flieht, bleibt vor ihm stehen: Der Boss wartet weiter.
func needs_battle() -> bool:
	if result != "" or not dialog.is_empty():
		return false
	if pending_battle.has(current):
		return true
	var type: String = node().type
	return (type == "kampf" or type == "boss") and not cleared.has(current)


## Ergebnis eines Kampfs am aktuellen Knoten: "sieg", "entkommen" oder "niederlage".
func finish_battle(outcome: String) -> void:
	last_reward = ""
	match outcome:
		"niederlage":
			result = "verloren"
		"sieg":
			var parts: Array[String] = []
			if node().type == "boss":
				result = "geschafft"
			else:
				var reward := _stage_for(node().column).get("reward", {}) as Dictionary
				var loot := {}
				for key: String in reward:
					var span: Array = reward[key]
					loot[key] = _rng.randi_range(int(span[0]), int(span[1]))
				parts = _apply(loot)
				if pending_battle.has(current):
					parts.append_array(_apply(pending_battle[current]))
			pending_battle.erase(current)
			cleared[current] = outcome
			last_reward = " · ".join(parts)
			ship.end_combat()
		"entkommen":
			pending_battle.erase(current)
			if node().type != "boss":
				cleared[current] = outcome
			ship.end_combat()


# --- Dialoge ---


## Wählt eine Option im offenen Dialog. Falsch, wenn sie nicht verfügbar ist.
func choose(index: int) -> bool:
	if dialog.is_empty() or index < 0 or index >= dialog.choices.size() or not dialog.choices[index].enabled:
		return false
	match _ctx.kind:
		"event":
			_choose_event(index)
		"result":
			_close_result()
		"shop":
			_choose_shop(index)
		"repair":
			_choose_repair(index)
	return true


func _open_event(id: String) -> void:
	var e := events.get_event(id)
	if e.is_empty():
		dialog = {}
		return
	var choices: Array[Dictionary] = []
	var options: Array[Dictionary] = []
	for c: Dictionary in e.choices:
		var req: Dictionary = c.get("requires", {})
		if req.has("flag") and not flags.has(req.flag):
			continue  # Ansehens-Optionen erscheinen nur, wenn man sie hat
		var cost: Dictionary = c.get("cost", {})
		var label: String = c.text
		if not cost.is_empty():
			label += " (%s)" % _cost_text(cost)
		var enabled := _can_pay(cost) and ship.crew.size() >= int(req.get("crew_min", 0))
		choices.append({"text": label, "enabled": enabled, "special": req.has("flag")})
		options.append(c)
	dialog = {"title": e.title, "text": e.text, "scene": e.get("scene", ""), "choices": choices}
	_ctx = {"kind": "event", "id": id, "options": options}


func _choose_event(index: int) -> void:
	var choice: Dictionary = _ctx.options[index]
	_pay(choice.get("cost", {}))
	var outcomes: Array = choice.outcomes
	var total := 0.0
	for o: Dictionary in outcomes:
		total += float(o.get("weight", 1.0))
	var roll := _rng.randf() * total
	var outcome: Dictionary = outcomes.back()
	for o: Dictionary in outcomes:
		roll -= float(o.get("weight", 1.0))
		if roll <= 0.0:
			outcome = o
			break
	var parts := _apply(outcome.get("effects", {}))
	var text: String = outcome.text
	if not parts.is_empty():
		text += "\n\n" + " · ".join(parts)
	var follow := "Kampf!" if outcome.get("battle", false) else "Weiter"
	if result == "verloren":
		follow = "Run vorbei"
	dialog = {"title": dialog.title, "text": text, "scene": dialog.scene,
		"choices": [{"text": follow, "enabled": true, "special": false}]}
	_ctx = {"kind": "result", "battle": outcome.get("battle", false), "victory": outcome.get("victory", {}),
		"next": outcome.get("next", "")}


func _close_result() -> void:
	var ctx := _ctx
	dialog = {}
	_ctx = {}
	if result != "":
		return
	if ctx.next != "":
		_open_event(ctx.next)
	elif ctx.battle:
		pending_battle[current] = ctx.victory


# --- Händler und Reparaturstation ---


func _discount() -> float:
	return float(rules.get("guild_discount", 0.0)) if flags.has("gilde_freund") else 0.0


func _price(base: int) -> int:
	return maxi(1, roundi(base * (1.0 - _discount())))


func _shop_offers() -> Array[Dictionary]:
	var s: Dictionary = rules.get("shop", {})
	var amount := int(s.get("hull_amount", 5))
	var missing := ship.max_hull - ship.hull
	return [
		{"text": "1 Treibstoff kaufen", "cost": {"scrap": _price(int(s.get("fuel_price", 3)))}, "fuel": 1},
		{"text": "Hülle +%d reparieren" % mini(amount, missing), "cost": {"scrap": _price(int(s.get("hull_price", 8)))},
			"hull": amount, "needs_damage": true},
		{"text": "Hülle +%d gegen Treibstoff" % mini(int(s.get("hull_for_fuel", 3)), missing), "cost": {"fuel": 1},
			"hull": int(s.get("hull_for_fuel", 3)), "needs_damage": true},
	]


func _open_shop() -> void:
	var text := "Ein Handelsposten der Gilde. Bezahlt wird in Rohstoffen oder Treibstoff."
	if flags.has("gilde_freund"):
		text += " Euer Gildenbrief bringt %d %% Rabatt." % roundi(_discount() * 100.0)
	if _shop_note != "":
		text += "\n\n" + _shop_note
	var choices: Array[Dictionary] = []
	for offer in _shop_offers():
		var enabled: bool = _can_pay(offer.cost) and not (offer.get("needs_damage", false) and ship.hull >= ship.max_hull)
		choices.append({"text": "%s (%s)" % [offer.text, _cost_text(offer.cost)], "enabled": enabled, "special": false})
	choices.append({"text": "Ablegen", "enabled": true, "special": false})
	dialog = {"title": "Händler", "text": text, "scene": "station", "choices": choices}
	_ctx = {"kind": "shop"}


func _choose_shop(index: int) -> void:
	var offers := _shop_offers()
	if index >= offers.size():
		dialog = {}
		_ctx = {}
		return
	var offer: Dictionary = offers[index]
	_pay(offer.cost)
	var effects := {}
	for key in ["fuel", "hull"]:
		if offer.has(key):
			effects[key] = offer[key]
	_shop_note = "Gekauft: " + " · ".join(_apply(effects))
	_open_shop()


## Schäden außer der Hülle: beschädigte Systembalken, Lecks und Brände.
func ship_damage_count() -> int:
	return ship.system_damage() + ship.breaches.size() + ship.fires.size()


func _systems_price() -> int:
	var r: Dictionary = rules.get("repair_station", {})
	return ship_damage_count() * int(r.get("price_per_system", 2))


func _repair_offers() -> Array[Dictionary]:
	var r: Dictionary = rules.get("repair_station", {})
	var missing := ship.max_hull - ship.hull
	var broken := ship_damage_count() > 0
	var offers: Array[Dictionary] = []
	if flags.has("kolonie_dank"):
		offers.append({"text": "[Kolonie] Komplettreparatur auf Kosten der Gilde", "cost": {}, "hull_full": true, "systems": true,
			"special": true, "flag_used": "kolonie_dank", "useful": missing > 0 or broken})
	offers.append({"text": "Komplettreparatur", "cost": {"scrap": maxi(1, missing * int(r.get("price_per_hull", 1)) + _systems_price())},
		"hull_full": true, "systems": true, "useful": missing > 0 or broken})
	offers.append({"text": "Systeme und Lecks instand setzen", "cost": {"scrap": maxi(1, _systems_price())}, "systems": true, "useful": broken})
	offers.append({"text": "Hülle +%d" % mini(int(r.get("patch_amount", 5)), missing), "cost": {"scrap": int(r.get("patch_price", 5))},
		"hull": int(r.get("patch_amount", 5)), "useful": missing > 0})
	offers.append({"text": "Hülle +%d gegen Treibstoff" % mini(int(r.get("hull_per_fuel", 4)), missing), "cost": {"fuel": 1},
		"hull": int(r.get("hull_per_fuel", 4)), "useful": missing > 0})
	return offers


func _open_repair() -> void:
	var text := "Eine Reparaturstation mit Werftdock. Die Techniker arbeiten schnell, aber nicht umsonst."
	var broken := ship_damage_count()
	if broken > 0:
		text += " Schäden an Bord: %d." % broken
	if flags.has("kolonie_dank"):
		text += " Die Kolonie hat euch angekündigt: Eine Komplettreparatur geht aufs Haus."
	if _shop_note != "":
		text += "\n\n" + _shop_note
	var choices: Array[Dictionary] = []
	for offer in _repair_offers():
		var label: String = offer.text
		if not offer.cost.is_empty():
			label += " (%s)" % _cost_text(offer.cost)
		choices.append({"text": label, "enabled": _can_pay(offer.cost) and offer.useful, "special": offer.get("special", false)})
	choices.append({"text": "Ablegen", "enabled": true, "special": false})
	dialog = {"title": "Reparaturstation", "text": text, "scene": "station", "choices": choices}
	_ctx = {"kind": "repair"}


func _choose_repair(index: int) -> void:
	var offers := _repair_offers()
	if index >= offers.size():
		dialog = {}
		_ctx = {}
		return
	var offer: Dictionary = offers[index]
	_pay(offer.cost)
	if offer.has("flag_used"):
		flags.erase(offer.flag_used)
	var effects := {}
	for key in ["hull", "hull_full"]:
		if offer.has(key):
			effects[key] = offer[key]
	var parts := _apply(effects)
	if offer.get("systems", false) and ship_damage_count() > 0:
		parts.append("%d Schäden behoben" % ship_damage_count())
		ship.repair_systems()
	_shop_note = "Repariert: " + " · ".join(parts)
	_open_repair()


# --- Kosten und Effekte ---


func _can_pay(cost: Dictionary) -> bool:
	return fuel >= int(cost.get("fuel", 0)) and scrap >= int(cost.get("scrap", 0))


func _pay(cost: Dictionary) -> void:
	fuel -= int(cost.get("fuel", 0))
	scrap -= int(cost.get("scrap", 0))


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	if int(cost.get("scrap", 0)) > 0:
		parts.append("%d Rohstoffe" % int(cost.scrap))
	if int(cost.get("fuel", 0)) > 0:
		parts.append("%d Treibstoff" % int(cost.fuel))
	return ", ".join(parts) if not parts.is_empty() else "gratis"


## Wendet Effekte an und liefert sie als kurze Texte („+12 Rohstoffe“, „Hülle −3“ …).
func _apply(effects: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	var s := int(effects.get("scrap", 0))
	if s != 0:
		scrap = maxi(scrap + s, 0)
		parts.append("%+d Rohstoffe" % s)
	var f := int(effects.get("fuel", 0))
	if f != 0:
		fuel = maxi(fuel + f, 0)
		parts.append("%+d Treibstoff" % f)
	var before := ship.hull
	if effects.get("hull_full", false):
		ship.hull = ship.max_hull
	ship.hull = clampi(ship.hull + int(effects.get("hull", 0)), 0, ship.max_hull)
	if ship.hull != before:
		parts.append("Hülle %+d" % (ship.hull - before))
	if int(effects.get("crew_hp", 0)) != 0 and not ship.crew.is_empty():
		var member: CrewMember = ship.crew[_rng.randi() % ship.crew.size()]
		ship.hurt(member, -float(effects.crew_hp))
		parts.append("%s verletzt" % member.display_name if ship.crew.has(member) else "%s ist gestorben" % member.display_name)
	for i in int(effects.get("crew_lose", 0)):
		if ship.crew.is_empty():
			break
		var member: CrewMember = ship.crew[_rng.randi() % ship.crew.size()]
		ship.hurt(member, CrewMember.MAX_HP * 2.0)
		parts.append("%s ist gestorben" % member.display_name)
	for i in int(effects.get("crew_add", 0)):
		if ship.crew.size() >= MAX_CREW:
			parts.append("Kein Platz für weitere Crew")
			break
		var taken := ship.crew.map(func(m: CrewMember) -> String: return m.display_name)
		var free := CREW_NAMES.filter(func(n: String) -> bool: return not taken.has(n))
		var name: String = free[_rng.randi() % free.size()] if not free.is_empty() else "Neuling"
		if ship.add_crew_anywhere(name, "mensch"):
			parts.append("%s kommt an Bord" % name)
	if effects.has("flag"):
		flags[effects.flag] = true
		parts.append(_flag_text(effects.flag))
	ship.events.clear()  # Todesmeldungen gehören nicht in den nächsten Kampf
	if ship.is_destroyed() or ship.is_crew_dead():
		result = "verloren"
	return parts


static func _flag_text(flag: String) -> String:
	match flag:
		"gilde_freund":
			return "Gildenbrief: Händler billiger"
		"kolonie_dank":
			return "Dank der Kolonie: Gratisreparatur in der Reparaturstation"
	return "Ansehen gewonnen"


# --- Gegner ---


func _stage_for(column: int) -> Dictionary:
	var stage := {}
	for s: Dictionary in _enemy_table.get("stages", []):
		if column >= int(s.get("from_jump", 0)):
			stage = s
	return stage


## Welcher Gegner am Knoten wartet: {ship (Pfad), name, hull_bonus}. Pro Knoten fest,
## damit ein neu geladener Kampf denselben Gegner zeigt.
func enemy_spec(id := -1) -> Dictionary:
	if id < 0:
		id = current
	var n := map.node(id)
	if n.type == "boss":
		var boss: Dictionary = _enemy_table.get("boss", {})
		return {
			"ship": SHIPS_DIR % boss.get("ship", "piraten_kutter_schwer"),
			"name": boss.get("name", ""),
			"hull_bonus": int(boss.get("hull_bonus", 0)),
		}
	var stage := _stage_for(n.column)
	var pool: Array = stage.get("pool", [["piraten_kutter", 1.0]])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, id])
	var total := 0.0
	for entry: Array in pool:
		total += float(entry[1])
	var roll := rng.randf() * total
	var pick: String = pool[0][0]
	for entry: Array in pool:
		roll -= float(entry[1])
		if roll <= 0.0:
			pick = entry[0]
			break
	return {"ship": SHIPS_DIR % pick, "name": "", "hull_bonus": int(stage.get("hull_bonus", 0))}


## Baut das Gegnerschiff für den Knoten samt Besatzung (Kapitänin, Schütze, Mechaniker).
func create_enemy(id := -1) -> ShipState:
	var spec := enemy_spec(id)
	var layout := ShipLayout.load_json(spec.ship)
	for error in layout.validate():
		push_error("%s: %s" % [spec.ship, error])
	if spec.name != "":
		layout.display_name = spec.name
	var enemy := ShipState.new(layout)
	enemy.max_hull += spec.hull_bonus
	enemy.hull = enemy.max_hull
	for crew_spec in [["Kapitänin", "cockpit"], ["Schütze", "waffen"], ["Mechaniker", "schilde"]]:
		var console: Vector2i = layout.console_of(layout.room_index_by_id(crew_spec[1]))
		enemy.add_crew(crew_spec[0], "mensch", console, {crew_spec[1]: 1.0})
	return enemy
