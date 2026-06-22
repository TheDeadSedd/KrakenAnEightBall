extends Node
class_name RunHistorySystem

# Owns finalized run-history persistence only. Current-run tracking stays in
# RunStatsSystem; this writes once when Main.gd explicitly finalizes a run.
const HISTORY_FILE_PATH := "user://run_history.json"
const MAX_RUN_RECORDS := 25

var records: Array = []
var current_run_finalized := false


func _ready() -> void:
	load_history()


func load_history() -> void:
	records.clear()
	if not FileAccess.file_exists(HISTORY_FILE_PATH):
		return

	var file := FileAccess.open(HISTORY_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not read run history: %s" % FileAccess.get_open_error())
		return

	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Run history file was not a dictionary.")
		return

	var parsed_records: Variant = parsed.get("records", [])
	if not parsed_records is Array:
		return

	for record_value in parsed_records:
		if record_value is Dictionary:
			records.append((record_value as Dictionary).duplicate(true))
	_trim_records()


func save_finalized_run(stats_snapshot: Dictionary, final_doubloons: int) -> bool:
	if current_run_finalized:
		return false

	var previous_records: Array = records.duplicate(true)
	records.insert(0, _make_run_record(stats_snapshot, final_doubloons))
	_trim_records()
	if not _write_history():
		records = previous_records
		return false

	current_run_finalized = true
	return true


func get_records_snapshot() -> Array:
	return records.duplicate(true)


func get_history_path() -> String:
	return HISTORY_FILE_PATH


func clear_history() -> bool:
	records.clear()
	var write_succeeded := _write_history()
	if not write_succeeded:
		load_history()
	return write_succeeded


func _make_run_record(stats_snapshot: Dictionary, final_doubloons: int) -> Dictionary:
	var doubloons_lost_to_penalties := _get_penalty_doubloons_lost(stats_snapshot)
	return {
		"timestamp": Time.get_datetime_string_from_system(false, false),
		"run_duration": maxf(float(stats_snapshot.get("run_time_seconds", 0.0)), 0.0),
		"final_doubloons": maxi(final_doubloons, 0),
		"doubloons_earned": maxi(int(stats_snapshot.get("doubloons_earned", 0)), 0),
		"doubloons_spent": maxi(int(stats_snapshot.get("doubloons_spent", 0)), 0),
		"doubloons_lost": doubloons_lost_to_penalties,
		"doubloons_lost_to_penalties": doubloons_lost_to_penalties,
		"shots_taken": maxi(int(stats_snapshot.get("shots_taken", 0)), 0),
		"balls_sunk": maxi(int(stats_snapshot.get("balls_sunk", 0)), 0),
		"highest_pocket_streak": maxi(int(stats_snapshot.get("highest_pocket_streak", 1)), 1),
		"interventions_triggered": maxi(int(stats_snapshot.get("interventions_triggered", 0)), 0),
		"contraband_found": maxi(int(stats_snapshot.get("contraband_found", 0)), 0),
		"treasure_claimed": maxi(int(stats_snapshot.get("treasure_claimed", 0)), 0),
		"final_ball_count": maxi(int(stats_snapshot.get("current_ball_count", 0)), 0),
		"passage_completed": bool(stats_snapshot.get("passage_completed", false)),
		"remaining_passage": maxi(int(stats_snapshot.get("remaining_passage", 0)), 0),
		"voyage_marks_awarded": maxi(int(stats_snapshot.get("voyage_marks_awarded", 0)), 0),
		"kraken_favor_earned": maxi(int(stats_snapshot.get("kraken_favor_earned", 0)), 0),
		"total_kraken_favor_after_run": maxi(int(stats_snapshot.get("total_kraken_favor_after_run", 0)), 0),
	}


func _get_penalty_doubloons_lost(stats_snapshot: Dictionary) -> int:
	return maxi(int(stats_snapshot.get("doubloons_lost_to_penalties", stats_snapshot.get("doubloons_lost", 0))), 0)


func _trim_records() -> void:
	if records.size() > MAX_RUN_RECORDS:
		records.resize(MAX_RUN_RECORDS)


func _write_history() -> bool:
	var payload := {
		"version": 1,
		"records": records,
	}
	var file := FileAccess.open(HISTORY_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write run history: %s" % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	return true
