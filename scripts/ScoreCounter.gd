extends Node

@onready var player: CharacterBody2D = get_parent()
@onready var score_label: Label = get_node("/root/World/CanvasLayer/ScoreLabel") # Убедитесь, что этот путь совпадает с вашей сценой

var start_y: float = 0.0
var max_score: int = 0

func _ready() -> void:
	# Запоминаем стартовую позицию игрока по вертикали
	start_y = player.global_position.y
	# Устанавливаем начальный текст на экране
	score_label.text = "Счет: 0"

func _process(_delta: float) -> void:
	# Считаем пройденное расстояние (вверх — это уменьшение Y)
	var distance = start_y - player.global_position.y
	
	# Конвертируем пиксели в условные метры (100 пикселей = 1 метр)
	var current_score = int(distance / 100)
	
	# Обновляем счетчик только если игрок поднялся выше своего рекорда
	if current_score > max_score:
		max_score = current_score
		score_label.text = "Счет: " + str(max_score)
