extends Node
## Считает очки по пройденному вверх расстоянию и передаёт их в HUD и SaveManager.

signal score_changed(new_score: int)
signal new_record_reached(score: int)   # Счёт впервые превысил сохранённый рекорд

@onready var player: CharacterBody2D = get_parent()
@onready var score_label: Label = %ScoreLabel

var start_y: float = 0.0
var max_score: int = 0
var _record_to_beat: int = 0
var _record_announced: bool = false
var score_multiplier: float = 1.0


func _ready() -> void:
	add_to_group("score_counter")
	start_y = player.global_position.y
	score_label.text = "0"
	_record_to_beat = SaveManager.get_location_best()
	score_multiplier = GameData.get_location(SaveManager.selected_location).score \
		* GameData.get_car(SaveManager.selected_car).score
	SaveManager.start_run()


func _process(_delta: float) -> void:
	var distance = start_y - player.global_position.y
	var current_score = int(distance / 100.0 * score_multiplier)

	if current_score > max_score:
		max_score = current_score
		score_label.text = str(max_score)
		SaveManager.update_run_score(max_score)
		score_changed.emit(max_score)

		if not _record_announced and _record_to_beat > 0 and max_score > _record_to_beat:
			_record_announced = true
			new_record_reached.emit(max_score)
