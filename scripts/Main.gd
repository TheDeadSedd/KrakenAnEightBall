extends Node2D

@onready var table: BilliardsTable = $Table
@onready var status_label: Label = $CanvasLayer/HUD/StatusLabel
@onready var result_label: Label = $CanvasLayer/HUD/ResultLabel


func _ready() -> void:
	table.status_text_changed.connect(_on_status_text_changed)
	table.game_finished.connect(_on_game_finished)
	result_label.text = ""


func _on_status_text_changed(text: String) -> void:
	status_label.text = text


func _on_game_finished(text: String) -> void:
	result_label.text = text
