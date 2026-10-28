extends Control
## Панель заданий во время заезда: три строки с полоской прогресса.
## Выполненное задание вспыхивает и отмечается галочкой.

const ROW_H := 30.0
var _flash: Array = [0.0, 0.0, 0.0]
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220, 26 + ROW_H * Missions.SLOTS)
	size = custom_minimum_size
	Missions.progress_changed.connect(queue_redraw)
	Missions.mission_completed.connect(func(slot: int, _t2: String, _r: int):
		if slot >= 0:
			_flash[slot] = 1.0)


func _process(delta: float) -> void:
	_t += delta
	var any := false
	for i in _flash.size():
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - delta * 0.8)
			any = true
	if any:
		queue_redraw()


func _draw() -> void:
	# После финиша задания уже заменены новыми — панель прячется
	visible = Missions._active
	Art.rrect(self, Rect2(Vector2.ZERO, size), Color(Art.UI_PANEL, 0.82), 12)
	draw_string(Art.font_bold, Vector2(12, 18), "ЗАДАНИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Art.UI_MUTED)
	for i in Missions.SLOTS:
		var m := Missions.get_slot(i)
		if m.is_empty():
			continue
		var y := 24.0 + i * ROW_H
		var done: bool = i in Missions.completed_this_run
		var here := Missions.is_available_here(m)
		var target := Missions.target_of(m)
		var prog: int = Missions.progress[i]
		var k := clampf(float(prog) / maxf(target, 1), 0.0, 1.0)
		if _flash[i] > 0.0:
			Art.rrect(self, Rect2(4, y - 2, size.x - 8, ROW_H), Color(Art.GREEN, 0.35 * _flash[i]), 8)
		var col := Art.GREEN if done else (Art.UI_TEXT if here else Art.UI_MUTED)
		# Галочка или кружок
		var c := Vector2(20, y + 10)
		if done:
			draw_circle(c, 8, Art.GREEN)
			draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3), c + Vector2(4, -3)]), Art.INK, 2.0, true)
		else:
			draw_arc(c, 7, 0, TAU, 20, Color(col, 0.7), 2.0, true)
		# Число справа уже показывает цель («0/4»), поэтому «: 4» в названии не повторяем.
		# Длинное название уменьшается, а не обрезается («Уйти от коллектор…»)
		var text := Missions.short_text(m).trim_suffix(": %d" % target)
		var max_w := size.x - 34.0 - 44.0
		var fs := 13
		while fs > 10 and Art.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			fs -= 1
		draw_string(Art.font_bold, Vector2(34, y + 14), text, HORIZONTAL_ALIGNMENT_LEFT, max_w, fs, col)
		var count := "✓" if done else "%d/%d" % [prog, target]
		draw_string(Art.font_bold, Vector2(size.x - 48, y + 14), count, HORIZONTAL_ALIGNMENT_RIGHT, 38, 12,
			Art.GREEN if done else Art.UI_MUTED)
		# Полоска прогресса
		var bar := Rect2(34, y + 20, size.x - 46, 4)
		Art.rrect(self, bar, Color(Art.UI_PANEL_LIGHT), 2)
		if k > 0.0:
			Art.rrect(self, Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Art.GREEN if done else Art.YELLOW, 2)
