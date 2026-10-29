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
var bonus_score: int = 0        # очки за трюки («на волоске» и т.п.)


func _ready() -> void:
	add_to_group("score_counter")
	start_y = player.global_position.y
	score_label.text = "0"
	_record_to_beat = SaveManager.get_location_best()
	var car := GameData.get_car(SaveManager.selected_car)
	score_multiplier = GameData.get_location(SaveManager.selected_location).score * car.score
	# «Родная» трасса машины (маршрутка в Омске) даёт дополнительный множитель
	if car.get("home", "") == GameData.get_location(SaveManager.selected_location).theme:
		score_multiplier *= car.get("home_score", 1.0)
	# Заезд дня — небольшой бонус к очкам
	if SaveManager.daily_mode:
		score_multiplier *= SaveManager.DAILY_BONUS
	# Испытание недели — бонус зависит от сложности правила
	if SaveManager.weekly_mode:
		score_multiplier *= SaveManager.weekly_rule().score
	# Сложность: «Спокойно» ×0,8, «Жёстко» ×1,3
	score_multiplier *= float(SaveManager.difficulty().score)
	SaveManager.start_run()
	# В вызове цель — результат друга, в «Кто дальше» — лучший результат партии
	if SaveManager.challenge_mode:
		_record_to_beat = int(SaveManager.challenge.get("score", 0))
	elif SaveManager.party_mode:
		_record_to_beat = 0
		for row in SaveManager.party_table():
			_record_to_beat = maxi(_record_to_beat, int(row.best))


var _far: float = 0.0            # самая дальняя точка, докуда доехали
var _double_bonus: float = 0.0   # добавка от бонуса «×2»


func _process(_delta: float) -> void:
	var distance = start_y - player.global_position.y
	if distance > _far:
		if player.double_points_left > 0.0:
			_double_bonus += (distance - _far) / 100.0 * score_multiplier
		_far = distance
	var current_score = int(distance / 100.0 * score_multiplier + _double_bonus) + bonus_score

	if current_score > max_score:
		max_score = current_score
		score_label.text = str(max_score)
		SaveManager.update_run_score(max_score)
		score_changed.emit(max_score)
		Missions.event("score", max_score)

		if not _record_announced and _record_to_beat > 0 and max_score > _record_to_beat:
			_record_announced = true
			new_record_reached.emit(max_score)


## Бонус за опасный манёвр — сразу добавляется к счёту
func add_bonus(points: int) -> void:
	if player.double_points_left > 0.0:
		points *= 2
	bonus_score += int(points * score_multiplier)
	_process(0.0)     # сразу пересчитываем счёт (важно, если заезд как раз заканчивается)
