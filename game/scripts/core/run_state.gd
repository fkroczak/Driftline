class_name RunState
extends RefCounted
## Ein Run: Modus, Sektor, Sternenkarte, Position, eigenes Schiff, Treibstoff und Rohstoffe,
## offene Dialoge (Ereignis, Händler, Reparaturstation). Reine Logik, keine Nodes.
##
## Modi:
## - "jagd" (Die Jagd): HUNT_SECTORS Sektoren mit je einem Boss am Ausgang. Die Jägerfront rückt
##   mit jedem Sprung um FRONT_STEP von links vor; nach HUNT_JUMPS Sprüngen hat sie den Ausgang
##   erreicht. Springen kann man trotzdem, solange Treibstoff da ist, aber jedes System hinter der
##   Front ist von den Jägern besetzt: Wer dort ankommt, muss gegen eine Jäger-Fregatte kämpfen
##   (`hunter_battle`), Händler und Ereignisse sind dort weg. Nach dem Sieg über den Boss geht es
##   in den nächsten Sektor (`sector_cleared`, dann `next_sector`), nach dem letzten ist der Run geschafft.
## - "endlos" (Endloses Universum): keine Front, kein Boss. Am Ausgang geht es sofort in den
##   nächsten Sektor; die Gegner werden mit jedem Sektor stärker. Punktzahl = erreichter Sektor.
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
const MODE_HUNT := "jagd"
const MODE_ENDLESS := "endlos"
## Jagd: so viele Sprünge, bis die Front den Ausgang erreicht, und so viele Sektoren bis zum Ziel.
const HUNT_JUMPS := 10
const HUNT_SECTORS := 4
## Lage der Jägerfront (x auf der Karte, 0..1) am Sektorstart und ihr Vorrücken je Sprung.
const FRONT_START := -0.12
const FRONT_STEP := 0.1
## Wellenform der Front (Ausschlag in x).
const FRONT_WAVE := 0.025

var seed_value := 0
var mode := MODE_HUNT
## Aktueller Sektor (Universum), ab 1.
var sector := 1
var map: StarMap
var ship: ShipState
var events: EventBook
## Aktueller Knoten (ID in map.nodes).
var current := 0
## Sprünge im aktuellen Sektor und im ganzen Run.
var jumps := 0
var total_jumps := 0
## Jägerfront (nur Jagd): x-Lage auf der Karte.
var front := FRONT_START
## Am aktuellen Knoten greifen die Jäger an (Knoten liegt hinter der Front).
var hunter_battle := false
## Boss besiegt, der Sprung in den nächsten Sektor steht an.
var sector_cleared := false
## Gerade aus einem Kampf geflohen: Der Sprung zum gewählten Ziel folgt sofort (jump_to).
var fleeing := false
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
## "" solange der Run läuft, sonst "geschafft" (letzter Boss besiegt) oder "verloren".
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


func _init(p_seed := 0, p_mode := MODE_HUNT) -> void:
	seed_value = p_seed if p_seed != 0 else randi()
	mode = p_mode if p_mode in [MODE_HUNT, MODE_ENDLESS] else MODE_HUNT
	_rng.seed = seed_value
	ship = create_player_ship()
	events = EventBook.load_default()
	_enemy_table = _load_json(ENEMIES_PATH)
	rules = _load_json(RUN_PATH)
	fuel = int(rules.get("start_fuel", 6))
	scrap = int(rules.get("start_scrap", 10))
	_setup_sector()


## Neue Karte für den aktuellen Sektor; Schiff, Crew und Ressourcen bleiben.
func _setup_sector() -> void:
	map = StarMap.generate(hash([seed_value, sector]), "boss" if mode == MODE_HUNT else "ausgang")
	current = map.start_id()
	visited = {current: true}
	cleared = {}
	pending_battle = {}
	node_events = {}
	jumps = 0
	front = FRONT_START
	hunter_battle = false
	sector_cleared = false
	var used := {}
	for n in map.nodes:
		if n.type == "ereignis":
			var id := events.pick("ereignis", _rng, used)
			node_events[n.id] = id
			used[id] = true


## Sprung in den nächsten Sektor (nach dem Boss bzw. am Ausgang im Endlos-Modus).
func next_sector() -> void:
	sector += 1
	ship.end_combat()
	ship.jump_charge = 0.0
	_setup_sector()


static func _load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


static func create_player_ship() -> ShipState:
	var layout := ShipLayout.load_json(PLAYER_SHIP)
	for error in layout.validate():
		push_error("%s: %s" % [PLAYER_SHIP, error])
	var s := ShipState.new(layout)
	var captain := s.add_crew("Mara Voss", "mensch", Vector2i(9, 3), {"cockpit": 3.0, "waffen": 1.0})
	captain.role = CrewMember.ROLE_CAPTAIN
	s.add_crew("Jonas Reil", "mensch", Vector2i(6, 6), {"waffen": 3.0, "schilde": 1.0})
	s.add_crew("Ilka Brandt", "mensch", Vector2i(6, 0), {"schilde": 2.0, "antrieb": 2.0})
	s.in_combat = false
	return s


func node() -> Dictionary:
	return map.node(current)


## Sprünge im aktuellen Sektor.
func jumps_done() -> int:
	return jumps


func jump_cost() -> int:
	return int(rules.get("jump_cost", 1))


func is_hunt() -> bool:
	return mode == MODE_HUNT


## Lage der Front auf Höhe y (leicht gewellt).
func front_at(y: float, at_front := front) -> float:
	return at_front + FRONT_WAVE * sin(y * TAU * 1.5 + sector * 1.7)


## Liegt der Knoten hinter der Jägerfront? (Nur Jagd.)
func is_overrun(id: int, at_front := front) -> bool:
	if mode != MODE_HUNT:
		return false
	var p: Vector2 = map.node(id).pos
	return p.x <= front_at(p.y, at_front)


## Wie viele Sprünge noch, bis die Front den Knoten erreicht (0 = schon überrannt, -1 = nie).
func jumps_until_overrun(id: int) -> int:
	if mode != MODE_HUNT:
		return -1
	for k in 30:
		if is_overrun(id, front + k * FRONT_STEP):
			return k
	return -1


## Ein Notruf-Ereignis wartet an diesem Knoten (auf der Karte sichtbar).
func is_beacon(id: int) -> bool:
	return node_events.has(id) and events.get_event(node_events[id]).get("beacon", false)


func can_jump_to(id: int) -> bool:
	return result == "" and not sector_cleared and dialog.is_empty() and not needs_battle() \
		and fuel >= jump_cost() and node().links.has(id)


## Springt zum Knoten (auch zurück zu besuchten). Die Front rückt vor. Am Ziel öffnet sich je nach
## Typ ein Dialog (Ereignis beim ersten Besuch, Händler, Reparaturstation), hinter der Front greifen
## die Jäger an, und am Ausgang im Endlos-Modus geht es in den nächsten Sektor.
func jump_to(id: int) -> bool:
	if not can_jump_to(id):
		return false
	fuel -= jump_cost()
	fleeing = false
	ship.end_combat()
	_pass_ship_time(JUMP_SHIP_TIME)
	ship.jump_charge = 0.0  # am Ziel lädt der Antrieb neu
	current = id
	jumps += 1
	total_jumps += 1
	if mode == MODE_HUNT:
		front += FRONT_STEP
	var first_visit := not visited.has(id)
	visited[id] = true
	if result != "":
		return true
	if is_overrun(id):
		hunter_battle = true
		return true
	if mode == MODE_ENDLESS and node().type == "ausgang":
		next_sector()
		return true
	if first_visit or node().type in ["haendler", "reparatur"]:
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
	return result == "" and not sector_cleared and dialog.is_empty() and not needs_battle() and fuel < jump_cost() and node().type != "boss"


func send_distress() -> bool:
	if not can_send_distress():
		return false
	_open_event(events.pick("notsignal", _rng))
	return true


## Am aktuellen Knoten wartet ein Gegner, der noch nicht besiegt oder abgehängt ist.
## Wer vor dem Boss flieht, springt weg; der Boss wartet weiter am Ausgang.
func needs_battle() -> bool:
	if result != "" or sector_cleared or fleeing or not dialog.is_empty():
		return false
	if hunter_battle or pending_battle.has(current):
		return true
	var type: String = node().type
	return (type == "kampf" or type == "boss") and not cleared.has(current)


## Der wartende Gegner ist der Boss (nicht die Jäger und kein Ereigniskampf davor).
func is_boss_battle() -> bool:
	return needs_battle() and not hunter_battle and not pending_battle.has(current) and node().type == "boss"


## Ergebnis eines Kampfs am aktuellen Knoten: "sieg", "entkommen", "gegner_entkommen" oder "niederlage".
## Nach einer Flucht folgt der Sprung (jump_to) zum gewählten Ziel.
func finish_battle(outcome: String) -> void:
	last_reward = ""
	match outcome:
		"niederlage":
			result = "verloren"
		"sieg":
			var parts: Array[String] = []
			if hunter_battle:
				hunter_battle = false
				parts = _apply(_roll_loot(_enemy_table.get("hunter", {}).get("reward", {})))
			elif is_boss_battle():
				parts = _apply(_roll_loot(_enemy_table.get("boss", {}).get("reward", {})))
				cleared[current] = outcome
				if sector >= HUNT_SECTORS:
					result = "geschafft"
				else:
					sector_cleared = true
			else:
				var loot := _roll_loot(_stage_for(_depth(node().column)).get("reward", {}))
				loot["scrap"] = int(loot.get("scrap", 0)) + (sector - 1) * int(_enemy_table.get("scrap_per_sector", 0))
				parts = _apply(loot)
				if pending_battle.has(current):
					parts.append_array(_apply(pending_battle[current]))
				pending_battle.erase(current)
				cleared[current] = outcome
			last_reward = " · ".join(parts)
			ship.end_combat()
		"gegner_entkommen":
			# Der Gegner ist weggesprungen: keine Beute, das System ist danach ruhig.
			pending_battle.erase(current)
			hunter_battle = false
			cleared[current] = outcome
			ship.end_combat()
		"entkommen":
			pending_battle.erase(current)
			hunter_battle = false
			fleeing = true
			if node().type != "boss":
				cleared[current] = outcome
			ship.end_combat()


func _roll_loot(reward: Dictionary) -> Dictionary:
	var loot := {}
	for key: String in reward:
		var span: Array = reward[key]
		loot[key] = _rng.randi_range(int(span[0]), int(span[1]))
	return loot


## Punktzahl für die Bestenliste: erreichter Sektor (Endlos) bzw. geschaffte Sektoren (Jagd).
func score() -> int:
	return sector


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
		var label: String = Loc.t(c.text)
		if not cost.is_empty():
			label += " (%s)" % _cost_text(cost)
		var enabled := _can_pay(cost) and ship.crew.size() >= int(req.get("crew_min", 0))
		choices.append({"text": label, "enabled": enabled, "special": req.has("flag")})
		options.append(c)
	dialog = {"title": Loc.t(e.title), "text": Loc.t(e.text), "scene": e.get("scene", ""), "choices": choices}
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
	var text: String = Loc.t(outcome.text)
	if not parts.is_empty():
		text += "\n\n" + " · ".join(parts)
	var follow := Loc.t("Kampf!") if outcome.get("battle", false) else Loc.t("Weiter")
	if result == "verloren":
		follow = Loc.t("Run vorbei")
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
		{"text": Loc.t("1 Treibstoff kaufen"), "cost": {"scrap": _price(int(s.get("fuel_price", 3)))}, "fuel": 1},
		{"text": Loc.t("Hülle +%d reparieren") % mini(amount, missing), "cost": {"scrap": _price(int(s.get("hull_price", 8)))},
			"hull": amount, "needs_damage": true},
		{"text": Loc.t("Hülle +%d gegen Treibstoff") % mini(int(s.get("hull_for_fuel", 3)), missing), "cost": {"fuel": 1},
			"hull": int(s.get("hull_for_fuel", 3)), "needs_damage": true},
	]


func _open_shop() -> void:
	var text := Loc.t("Ein Handelsposten der Gilde. Bezahlt wird in Rohstoffen oder Treibstoff.")
	if flags.has("gilde_freund"):
		text += Loc.t(" Euer Gildenbrief bringt %d %% Rabatt.") % roundi(_discount() * 100.0)
	if _shop_note != "":
		text += "\n\n" + _shop_note
	var choices: Array[Dictionary] = []
	for offer in _shop_offers():
		var enabled: bool = _can_pay(offer.cost) and not (offer.get("needs_damage", false) and ship.hull >= ship.max_hull)
		choices.append({"text": "%s (%s)" % [offer.text, _cost_text(offer.cost)], "enabled": enabled, "special": false})
	choices.append({"text": Loc.t("Ablegen"), "enabled": true, "special": false})
	dialog = {"title": Loc.t("Händler"), "text": text, "scene": "station", "choices": choices}
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
	_shop_note = Loc.t("Gekauft: ") + " · ".join(_apply(effects))
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
		offers.append({"text": Loc.t("[Kolonie] Komplettreparatur auf Kosten der Gilde"), "cost": {}, "hull_full": true, "systems": true,
			"special": true, "flag_used": "kolonie_dank", "useful": missing > 0 or broken})
	offers.append({"text": Loc.t("Komplettreparatur"), "cost": {"scrap": maxi(1, missing * int(r.get("price_per_hull", 1)) + _systems_price())},
		"hull_full": true, "systems": true, "useful": missing > 0 or broken})
	offers.append({"text": Loc.t("Systeme und Lecks instand setzen"), "cost": {"scrap": maxi(1, _systems_price())}, "systems": true, "useful": broken})
	offers.append({"text": Loc.t("Hülle +%d") % mini(int(r.get("patch_amount", 5)), missing), "cost": {"scrap": int(r.get("patch_price", 5))},
		"hull": int(r.get("patch_amount", 5)), "useful": missing > 0})
	offers.append({"text": Loc.t("Hülle +%d gegen Treibstoff") % mini(int(r.get("hull_per_fuel", 4)), missing), "cost": {"fuel": 1},
		"hull": int(r.get("hull_per_fuel", 4)), "useful": missing > 0})
	return offers


func _open_repair() -> void:
	var text := Loc.t("Eine Reparaturstation mit Werftdock. Die Techniker arbeiten schnell, aber nicht umsonst.")
	var broken := ship_damage_count()
	if broken > 0:
		text += Loc.t(" Schäden an Bord: %d.") % broken
	if flags.has("kolonie_dank"):
		text += Loc.t(" Die Kolonie hat euch angekündigt: Eine Komplettreparatur geht aufs Haus.")
	if _shop_note != "":
		text += "\n\n" + _shop_note
	var choices: Array[Dictionary] = []
	for offer in _repair_offers():
		var label: String = offer.text
		if not offer.cost.is_empty():
			label += " (%s)" % _cost_text(offer.cost)
		choices.append({"text": label, "enabled": _can_pay(offer.cost) and offer.useful, "special": offer.get("special", false)})
	choices.append({"text": Loc.t("Ablegen"), "enabled": true, "special": false})
	dialog = {"title": Loc.t("Reparaturstation"), "text": text, "scene": "station", "choices": choices}
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
		parts.append(Loc.t("%d Schäden behoben") % ship_damage_count())
		ship.repair_systems()
	_shop_note = Loc.t("Repariert: ") + " · ".join(parts)
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
		parts.append(Loc.t("%d Rohstoffe") % int(cost.scrap))
	if int(cost.get("fuel", 0)) > 0:
		parts.append(Loc.t("%d Treibstoff") % int(cost.fuel))
	return ", ".join(parts) if not parts.is_empty() else Loc.t("gratis")


## Wendet Effekte an und liefert sie als kurze Texte („+12 Rohstoffe“, „Hülle −3“ …).
func _apply(effects: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	var s := int(effects.get("scrap", 0))
	if s != 0:
		scrap = maxi(scrap + s, 0)
		parts.append(Loc.t("%+d Rohstoffe") % s)
	var f := int(effects.get("fuel", 0))
	if f != 0:
		fuel = maxi(fuel + f, 0)
		parts.append(Loc.t("%+d Treibstoff") % f)
	var before := ship.hull
	if effects.get("hull_full", false):
		ship.hull = ship.max_hull
	ship.hull = clampi(ship.hull + int(effects.get("hull", 0)), 0, ship.max_hull)
	if ship.hull != before:
		parts.append(Loc.t("Hülle %+d") % (ship.hull - before))
	if int(effects.get("crew_hp", 0)) != 0 and not ship.crew.is_empty():
		var member: CrewMember = ship.crew[_rng.randi() % ship.crew.size()]
		ship.hurt(member, -float(effects.crew_hp))
		parts.append(Loc.t("%s verletzt") % member.display_name if ship.crew.has(member) else Loc.t("%s ist gestorben") % member.display_name)
	for i in int(effects.get("crew_lose", 0)):
		if ship.crew.is_empty():
			break
		var member: CrewMember = ship.crew[_rng.randi() % ship.crew.size()]
		ship.hurt(member, CrewMember.MAX_HP * 2.0)
		parts.append(Loc.t("%s ist gestorben") % member.display_name)
	for i in int(effects.get("crew_add", 0)):
		if ship.crew.size() >= MAX_CREW:
			parts.append(Loc.t("Kein Platz für weitere Crew"))
			break
		var species: String = effects.get("species", Species.pick(_rng))
		var taken := ship.crew.map(func(m: CrewMember) -> String: return m.display_name)
		var free: Array = (Species.value(species, "names", []) as Array).filter(func(n: String) -> bool: return not taken.has(n))
		var name: String = free[_rng.randi() % free.size()] if not free.is_empty() else Loc.t("Neuling")
		if ship.add_crew_anywhere(name, species):
			parts.append(Loc.t("%s (%s) kommt an Bord") % [name, Species.display_name(species)])
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
			return Loc.t("Gildenbrief: Händler billiger")
		"kolonie_dank":
			return Loc.t("Dank der Kolonie: Gratisreparatur in der Reparaturstation")
	return Loc.t("Ansehen gewonnen")


# --- Gegner ---


## Fortschritt für die Gegnerstufe: Lage auf der Karte plus Sektor.
func _depth(column: int) -> int:
	return column + (sector - 1) * int(_enemy_table.get("depth_per_sector", 3))


func _stage_for(depth: int) -> Dictionary:
	var stage := {}
	for s: Dictionary in _enemy_table.get("stages", []):
		if depth >= int(s.get("from_jump", 0)):
			stage = s
	return stage


## Welcher Gegner am Knoten wartet: {ship (Pfad), name, hull_bonus}. Pro Knoten fest,
## damit ein neu geladener Kampf denselben Gegner zeigt. Hinter der Front sind es die Jäger.
func enemy_spec(id := -1) -> Dictionary:
	if id < 0:
		id = current
	var n := map.node(id)
	var per_sector := (sector - 1) * int(_enemy_table.get("hull_per_sector", 0))
	if id == current and hunter_battle:
		var hunter: Dictionary = _enemy_table.get("hunter", {})
		var extra := maxi(jumps - HUNT_JUMPS, 0) * int(hunter.get("hull_per_late_jump", 0))
		return {
			"ship": SHIPS_DIR % hunter.get("ship", "jaeger_fregatte"),
			"name": hunter.get("name", ""),
			"hull_bonus": int(hunter.get("hull_bonus", 0)) + per_sector + extra,
		}
	if n.type == "boss":
		var boss: Dictionary = _enemy_table.get("boss", {})
		return {
			"ship": SHIPS_DIR % boss.get("ship", "piraten_kutter_schwer"),
			"name": boss.get("name", ""),
			"hull_bonus": int(boss.get("hull_bonus", 0)) + (sector - 1) * int(boss.get("hull_per_sector", 0)),
		}
	var stage := _stage_for(_depth(n.column))
	var pool: Array = stage.get("pool", [["piraten_kutter", 1.0]])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, sector, id])
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
	return {"ship": SHIPS_DIR % pick, "name": "", "hull_bonus": int(stage.get("hull_bonus", 0)) + per_sector}


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
	for crew_spec in [[Loc.t("Kapitänin"), "cockpit"], [Loc.t("Schütze"), "waffen"], [Loc.t("Mechaniker"), "schilde"]]:
		var console: Vector2i = layout.console_of(layout.room_index_by_id(crew_spec[1]))
		enemy.add_crew(crew_spec[0], "mensch", console, {crew_spec[1]: 1.0})
	return enemy
