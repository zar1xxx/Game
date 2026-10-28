extends Control
## Экран проигрыша: причина, итоговый счёт, рекорд и кнопки.

const MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var reason_label: Label = $Center/Panel/VBox/ReasonLabel
@onready var score_label: Label = $Center/Panel/VBox/ScoreResult
@onready var best_label: Label = $Center/Panel/VBox/BestResult
@onready var new_record_label: Label = $Center/Panel/VBox/NewRecordLabel
@onready var restart_button: Button = $Center/Panel/VBox/Buttons/RestartButton
@onready var menu_button: Button = $Center/Panel/VBox/Buttons/MenuButton

var _time: float = 0.0


func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	new_record_label.hide()


func show_result(reason: String, score: int, best: int, is_new_record: bool) -> void:
	reason_label.text = reason
	score_label.text = "Ваш счёт: %d" % score
	best_label.text = "Рекорд: %d" % best
	new_record_label.visible = is_new_record
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	restart_button.grab_focus()


func _process(delta: float) -> void:
	if visible and new_record_label.visible:
		_time += delta
		new_record_label.modulate.a = 0.6 + 0.4 * sin(_time * 6.0)


func _on_restart_pressed() -> void:
	# Снимаем игру с паузы перед перезапуском, иначе новый уровень тоже запустится замороженным
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
