extends Node2D
## Притемнение обочин во время заезда (v2.6). Тестировщики жаловались, что за пёстрыми
## кварталами по краям плохо видно трассу и бонусы. Город остаётся, но у бордюра он
## затемнён слегка, а к краю экрана — сильнее, и дорога с бонусами сразу бросается в глаза.
## Слой лежит над городом и фонарями, но под дорожными событиями (АЗС, ДПС) и машинами.

const NEAR := 0.16       # затемнение у самого бордюра (там же стоят достопримечательности Омска)
const MID := 0.5         # в 380 px от дороги
const FAR := 0.82        # у края экрана
const HALF_H := 1400.0   # с запасом на отъезд камеры и высокие экраны планшетов


func _ready() -> void:
	z_as_relative = false
	z_index = -7


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position.y = cam.global_position.y


func _draw() -> void:
	var left := Art.ROAD_LEFT - 6.0
	var right := Art.ROAD_RIGHT + 6.0
	_band(left, left - 380.0, NEAR, MID)
	_band(left - 380.0, left - 1600.0, MID, FAR)
	_band(right, right + 380.0, NEAR, MID)
	_band(right + 380.0, right + 1600.0, MID, FAR)


## Полоса от x0 (затемнение a0) до x1 (затемнение a1) на всю высоту. Плавный переход
## собран из узких прямоугольников: draw_polygon с цветами вершин в GL Compatibility
## на части видеокарт не рисовался вовсе.
func _band(x0: float, x1: float, a0: float, a1: float) -> void:
	const STEPS := 12
	var w := (x1 - x0) / STEPS
	for i in STEPS:
		var a := lerpf(a0, a1, (i + 0.5) / STEPS)
		var xa := x0 + w * i
		draw_rect(Rect2(minf(xa, xa + w), -HALF_H, absf(w), HALF_H * 2.0), Color(Art.INK, a))
