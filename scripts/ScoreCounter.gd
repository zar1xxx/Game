extends Node

# Добавляем новый сигнал (Новое!)
signal score_changed(new_score: int)

@onready var player: CharacterBody2D = get_parent()
@onready var score_label: Label = get_node("/root/World/CanvasLayer/ScoreLabel") 

var start_y: float = 0.0
var max_score: int = 0

func _ready() -> void:
	start_y = player.global_position.y
	score_label.text = "Счет: 0"

func _process(_delta: float) -> void:
	var distance = start_y - player.global_position.y
	var current_score = int(distance / 100)
	
	if current_score > max_score:
		max_score = current_score
		score_label.text = "Счет: " + str(max_score)
		
		# Излучаем сигнал и передаем туда актуальные очки (Новое!)
		score_changed.emit(max_score)
