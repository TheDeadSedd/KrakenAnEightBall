extends RefCounted
class_name DeveloperPreferences

const SAVE_PATH := "user://developer_preferences.cfg"
const SAVE_VERSION := 1
const SECTION_GENERAL := "developer"

var show_fps := false


func load_preferences() -> void:
	var config := ConfigFile.new()
	var load_error: Error = config.load(SAVE_PATH)
	if load_error != OK:
		show_fps = false
		return
	show_fps = bool(config.get_value(SECTION_GENERAL, "show_fps", false))


func set_show_fps(enabled: bool) -> void:
	if show_fps == enabled:
		return
	show_fps = enabled
	save_preferences()


func save_preferences() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(SECTION_GENERAL, "version", SAVE_VERSION)
	config.set_value(SECTION_GENERAL, "show_fps", show_fps)
	var save_error: Error = config.save(SAVE_PATH)
	if save_error != OK:
		push_warning("Developer preferences could not be saved: %s" % error_string(save_error))
