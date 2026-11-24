class_name Loc
extends RefCounted
## Mehrsprachigkeit. Der deutsche Text ist der Schlüssel: `Loc.t("Händler")` liefert auf Deutsch
## den Text selbst, in anderen Sprachen die Übersetzung aus `res://i18n/<sprache>.json`.
## Fehlt eine Übersetzung, bleibt der deutsche Text stehen (nichts bricht).
##
## Formatierte Texte: erst übersetzen, dann einsetzen, also `Loc.t("Sektor %d") % n`.
## Die Sprache kommt aus den Einstellungen (Settings "language"); leer = Systemsprache.
## Neue Texte: Schlüssel in `i18n/en.json` ergänzen, `python3 tools/i18n_check.py` findet fehlende.

const LANGUAGES := ["de", "en"]
const SOURCE := "de"
const PATH := "res://i18n/%s.json"

static var _lang := ""
static var _table: Dictionary = {}


## Aktuelle Sprache ("de" oder "en").
static func language() -> String:
	if _lang == "":
		set_language(str(Settings.get_value("language")))
	return _lang


## Setzt die Sprache; leer oder unbekannt = Systemsprache (Deutsch für de, sonst Englisch).
static func set_language(lang: String) -> void:
	if not LANGUAGES.has(lang):
		lang = SOURCE if OS.get_locale_language() == SOURCE else "en"
	_lang = lang
	_table = {}
	if lang == SOURCE:
		return
	var path := PATH % lang
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for key: String in parsed:
				if not key.begins_with("_") and parsed[key] is String:
					_table[key] = parsed[key]


static func t(text: String) -> String:
	if _lang == "":
		language()
	if text == "" or _lang == SOURCE:
		return text
	return _table.get(text, text)


## Alle Einträge der aktuellen Sprache (für Tests).
static func table() -> Dictionary:
	language()
	return _table
