extends RefCounted
class_name DevOptionRegistry

signal option_changed(option_id: String, value: Variant)

var _definitions: Dictionary = {}
var _definition_order: Array[String] = []


func register_option(definition_value: Dictionary) -> void:
	var option_id: String = str(definition_value.get("id", "")).strip_edges()
	if option_id.is_empty():
		push_warning("Dev Option registration skipped: missing stable id.")
		return

	var definition: Dictionary = definition_value.duplicate(true)
	definition["id"] = option_id
	definition["label"] = str(definition.get("label", option_id))
	definition["kind"] = str(definition.get("kind", "bool"))
	definition["description"] = str(
		definition.get("description", "Developer-only control for %s." % definition["label"])
	)
	if not definition.has("locations"):
		definition["locations"] = [{
			"tab_id": str(definition.get("tab_id", "")),
			"section": str(definition.get("section", "Other")),
		}]
	var locations_value: Variant = definition.get("locations", [])
	if locations_value is Array and not (locations_value as Array).is_empty():
		var primary_location_value: Variant = (locations_value as Array)[0]
		if primary_location_value is Dictionary:
			var primary_location: Dictionary = primary_location_value
			definition["tab_id"] = str(primary_location.get("tab_id", definition.get("tab_id", "")))
			definition["section"] = str(primary_location.get("section", definition.get("section", "Other")))
	if not _definitions.has(option_id):
		_definition_order.append(option_id)
	_definitions[option_id] = definition


func has_option(option_id: String) -> bool:
	return _definitions.has(option_id)


func get_option_count() -> int:
	return _definition_order.size()


func get_definition(option_id: String) -> Dictionary:
	var definition: Dictionary = _definitions.get(option_id, {})
	return definition.duplicate(true)


func get_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for option_id in _definition_order:
		var definition: Dictionary = _definitions.get(option_id, {})
		if not definition.is_empty():
			definitions.append(definition.duplicate(true))
	return definitions


func get_value(option_id: String) -> Variant:
	var definition: Dictionary = _definitions.get(option_id, {})
	var getter: Callable = definition.get("getter", Callable())
	if getter.is_valid():
		return getter.call()
	return definition.get("default")


func set_value(option_id: String, value: Variant) -> void:
	var definition: Dictionary = _definitions.get(option_id, {})
	var setter: Callable = definition.get("setter", Callable())
	if not setter.is_valid():
		return
	setter.call(value)
	refresh_option(option_id)


func trigger_action(option_id: String) -> void:
	var definition: Dictionary = _definitions.get(option_id, {})
	var action: Callable = definition.get("action", Callable())
	if action.is_valid():
		action.call()


func refresh_option(option_id: String) -> void:
	if not _definitions.has(option_id):
		return
	option_changed.emit(option_id, get_value(option_id))


func refresh_all() -> void:
	for option_id in _definition_order:
		refresh_option(option_id)


func search(query: String) -> Array[Dictionary]:
	var normalized_query: String = _normalize_search_text(query)
	if normalized_query.is_empty():
		return []
	var terms: PackedStringArray = normalized_query.split(" ", false)
	var matches: Array[Dictionary] = []
	for option_id in _definition_order:
		var definition: Dictionary = _definitions.get(option_id, {})
		var haystack: String = _make_search_haystack(definition)
		var matched := true
		for term in terms:
			if not haystack.contains(term):
				matched = false
				break
		if matched:
			matches.append(definition.duplicate(true))
	return matches


func _make_search_haystack(definition: Dictionary) -> String:
	var values: Array[String] = [
		str(definition.get("id", "")),
		str(definition.get("label", "")),
		str(definition.get("tab_id", "")),
		str(definition.get("section", "")),
		str(definition.get("description", "")),
		str(definition.get("impact", "")),
		str(definition.get("on_effect", "")),
		str(definition.get("off_effect", "")),
		str(definition.get("low_effect", "")),
		str(definition.get("high_effect", "")),
	]
	for location_value in definition.get("locations", []):
		if location_value is Dictionary:
			values.append(str((location_value as Dictionary).get("tab_id", "")))
			values.append(str((location_value as Dictionary).get("section", "")))
	for keyword_value in definition.get("keywords", []):
		values.append(str(keyword_value))
	for alias_value in definition.get("aliases", []):
		values.append(str(alias_value))
	for choice_value in definition.get("choices", []):
		if choice_value is Dictionary:
			values.append(str((choice_value as Dictionary).get("label", "")))
			values.append(str((choice_value as Dictionary).get("description", "")))
	return _normalize_search_text(" ".join(values))


func _normalize_search_text(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	normalized = normalized.replace("_", " ").replace(".", " ").replace("&", " ")
	normalized = normalized.replace("\t", " ").replace("\n", " ").replace("\r", " ")
	return " ".join(normalized.split(" ", false))
