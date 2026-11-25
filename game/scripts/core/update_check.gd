class_name UpdateCheck
extends RefCounted
## Sucht in den GitHub-Releases des Repositorys eine neuere Version als die installierte.
## Reine Logik ohne Netz (testbar); Abfrage, Download und Banner: Autoload `Updater`.
##
## Versionen haben die Form `0.3.22`: `config/version` plus Build-Nummer, die der
## Release-Workflow einsetzt. Die Version steht im Namen der Release-Datei:
## `hullbound-0.3.22-debug.apk` (Android) bzw. `hullbound-0.3.22-unsigned.ipa` (iOS).
## Releases aus dem reinen iOS-Workflow (Tag `ipa-…`) zählen nicht, der zählt eigene Nummern.

## Zustand des Updates (Autoload Updater, Banner im Hauptmenü).
enum State {
	NONE,
	AVAILABLE,
	DOWNLOADING,
	READY,  ## APK liegt fertig geladen in user://updates/
	FAILED,  ## Download fehlgeschlagen
}

const REPOSITORY := "fkroczak/Hullbound"
const API_URL := "https://api.github.com/repos/%s/releases?per_page=20"
const FILE_PATTERNS := {
	"android": "^hullbound-(\\d+(?:\\.\\d+)+)-debug\\.apk$",
	"ios": "^hullbound-(\\d+(?:\\.\\d+)+)-unsigned\\.ipa$",
}


## "android", "ios" oder "" (dort wird nicht geprüft).
static func platform() -> String:
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("ios"):
		return "ios"
	return ""


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## "0.3.22" -> [0, 3, 22]; leer, wenn es keine Version ist.
static func parse_version(text: String) -> Array[int]:
	var parts: Array[int] = []
	for p in text.split("."):
		if not p.is_valid_int():
			return []
		parts.append(p.to_int())
	return parts


## Ist `a` neuer als `b`? Stelle für Stelle als Zahl verglichen (0.3.100 > 0.3.99).
static func is_newer(a: String, b: String) -> bool:
	var x := parse_version(a)
	var y := parse_version(b)
	for i in maxi(x.size(), y.size()):
		var u: int = x[i] if i < x.size() else 0
		var v: int = y[i] if i < y.size() else 0
		if u != v:
			return u > v
	return false


## Nur Builds aus dem Release-Workflow haben eine Build-Nummer; aus dem Editor (z. B. "0.3") nicht.
static func can_check(version: String) -> bool:
	return parse_version(version).size() >= 3


## Neueste Release-Datei für `plat`, die neuer ist als `current`, sonst null.
## `releases`: geparste Antwort von GET /repos/{repo}/releases.
static func find_update(releases: Array, plat: String, current: String) -> Offer:
	if not FILE_PATTERNS.has(plat):
		return null
	var pattern: String = FILE_PATTERNS[plat]
	var regex := RegEx.create_from_string(pattern)
	var best: Offer = null
	for item: Variant in releases:
		if not (item is Dictionary):
			continue
		var release: Dictionary = item
		var assets: Variant = release.get("assets")
		if release.get("draft", false) or str(release.get("tag_name", "")).begins_with("ipa-") \
				or not (assets is Array):
			continue
		var list: Array = assets
		for entry: Variant in list:
			var offer := _offer_from(entry, regex, str(release.get("html_url", "")))
			var floor_version := best.version if best else current
			if offer and is_newer(offer.version, floor_version):
				best = offer
	return best


## Eine Release-Datei als Offer, wenn ihr Name zum Muster passt und sie per HTTPS mit
## bekannter Größe kommt (sonst ließe sich der Download nicht prüfen); sonst null.
static func _offer_from(entry: Variant, regex: RegEx, page: String) -> Offer:
	if not (entry is Dictionary):
		return null
	var asset: Dictionary = entry
	var m := regex.search(str(asset.get("name", "")))
	var url := str(asset.get("browser_download_url", ""))
	var size: Variant = asset.get("size")
	if m == null or not url.begins_with("https://") or not (size is float or size is int):
		return null
	var bytes: float = size  # JSON liefert Zahlen als float
	if bytes <= 0.0:
		return null
	return Offer.new(m.get_string(1), m.get_string(0), url, int(bytes), page)


## Gefundenes Update.
class Offer:
	var version: String
	## Dateiname; passt zu FILE_PATTERNS, taugt also gefahrlos als Pfad in user://.
	var file: String
	var url: String
	var size: int
	## Release-Seite auf GitHub.
	var page: String

	func _init(p_version: String, p_file: String, p_url: String, p_size: int, p_page: String) -> void:
		version = p_version
		file = p_file
		url = p_url
		size = p_size
		page = p_page
