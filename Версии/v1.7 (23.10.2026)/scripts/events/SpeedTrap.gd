extends "res://scripts/events/RoadEvent.gd"
## Ограничение «60» и камера (или пост ДПС с радаром).
## Проехали мимо камеры быстрее 70 км/ч — штраф монетами.
## Пока действует ограничение, полиция за медленную езду не цепляется.

const LIMIT := 60.0
const TOLERANCE := 10.0           # «нештрафуемые» +10 км/ч
const CHECK := 1050.0             # где стоит камера (от знака)
const END_SIGN := 1230.0

var officer: bool = false         # вместо камеры — инспектор с радаром
var checked: bool = false
var _flash: float = 0.0
var _passed_ok: bool = false


func _init() -> void:
	kind = "camera"
	length = END_SIGN + 60.0


func start() -> void:
	if officer:
		toast("Знак «60» и пост ДПС с радаром — сбрось скорость!", Art.YELLOW, 2.6)
	else:
		toast("Знак «60» и камера впереди — сбрось скорость!", Art.YELLOW, 2.6)


func fine_amount() -> int:
	return 100 if officer else 50


func _update(p, delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.0)
	if checked or p.global_position.y > wy(CHECK):
		return
	checked = true
	var kmh: float = p.current_speed * KMH
	if kmh > LIMIT + TOLERANCE:
		_fine(p, kmh)
	else:
		_passed_ok = true
		add_score(30)
		Missions.event("camera_ok")
		Sound.play("coin", -4.0, 1.1, 0.0)
		popup_at_player("+30", Art.GREEN)
		var ok_text: String = "Инспектор разочарованно опускает радар. Скорость в норме!" if officer \
			else ["Скорость в норме. Счастливого пути!", "Камера вас даже не заметила"].pick_random()
		toast(ok_text + " +30", Art.GREEN, 2.2)


func _fine(p, kmh: float) -> void:
	_flash = 1.0
	var amount := fine_amount()
	var paid: int = manager.charge_fine(amount) if manager else 0
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.fx and hud.fx.has_method("flash_white") and not officer:
		hud.fx.flash_white()
	if officer:
		Sound.play("beep", -2.0, 1.6, 0.0)
		Sound.play("horn", -8.0, 1.3, 0.0)
	else:
		Sound.play("beep", -4.0, 2.0, 0.0)
	MobileInput.vibrate(60)
	Pickup.burst(p, Art.RED, "−%d монет" % paid if paid > 0 else "Штраф!", "")
	var who := "Инспектор: %d км/ч при знаке 60!" % int(kmh) if officer else "Камера: %d км/ч при знаке 60!" % int(kmh)
	if paid < amount and paid == 0:
		toast(who + " Штраф выписан, но платить нечем", Art.RED, 2.6)
	else:
		toast(who + " Штраф %d монет" % paid, Art.RED, 2.6)


func hud_info(p) -> Dictionary:
	if checked:
		return {}
	var dist_sign: float = p.global_position.y - global_position.y
	if dist_sign > 700.0:
		return {}
	var dist: float = p.global_position.y - wy(CHECK)
	return {"title": "Пост ДПС" if officer else "Камера", "speed_limit": LIMIT, "tolerance": TOLERANCE,
		"kmh": p.current_speed * KMH, "dist": maxf(dist, 0.0) * 0.1, "color": Art.YELLOW}


func get_lights() -> Array:
	var out := [[Vector2(Art.ROAD_RIGHT + 24, wy(CHECK)), 110.0 + 200.0 * _flash, 0.8 + _flash]]
	if officer:
		out.append([Vector2(Art.ROAD_RIGHT + 90, wy(CHECK + 30)), 150.0, 0.9])
	return out


func _draw() -> void:
	# Знаки «60» с обеих сторон дороги
	for x in [Art.ROAD_LEFT - 24, Art.ROAD_RIGHT + 24]:
		draw_round_sign(Vector2(x, 0), 20, Art.LINE_WHITE, Art.RED, "60", Art.INK, 15)
	if not officer:
		draw_plate(Rect2(Art.ROAD_RIGHT + 6, 24, 38, 18), Art.LINE_WHITE, "ФОТО", Art.INK, 8)
	# «60» на асфальте каждой полосы
	for lane in Art.LANES:
		Art.text_center(self, Vector2(lane_center(lane), -260), "60", 40, Color(1, 1, 1, 0.33), true)
	var cp := Vector2(Art.ROAD_RIGHT + 24, -CHECK)
	if officer:
		# Машина ДПС на обочине и инспектор с радаром
		Art.draw_car(self, 104, 52, Color("eef0f6"), {"deco": "police", "lights": true, "time": _t,
			"base": Transform2D(0.0, Vector2(Art.ROAD_RIGHT + 90, -CHECK - 40))})
		var blink := int(_t * 6.0) % 2 == 0
		Art.glow(self, Vector2(Art.ROAD_RIGHT + 80, -CHECK - 44), 50, Color(1.0, 0.2, 0.25, 0.4 if blink else 0.1))
		Art.glow(self, Vector2(Art.ROAD_RIGHT + 100, -CHECK - 44), 50, Color(0.25, 0.45, 1.0, 0.1 if blink else 0.4))
		draw_person(cp, Color("c6ff3d"), Color("e8b48a"), PI * 0.5, Color("2d3a5c"))
		# Радар направлен на встречный поток (вниз, к игроку)
		var gun := cp + Vector2(-10, 10)
		draw_line(cp + Vector2(-6, 2), gun, Color("2f3242"), 4.0)
		Art.rrect(self, Rect2(gun - Vector2(6, 2), Vector2(12, 12)), Art.YELLOW, 3, 1, Art.INK)
		if _flash > 0.0:
			Art.glow(self, gun, 60, Color(1, 0.3, 0.3, _flash))
	else:
		# Камера на столбе, смотрит навстречу машинам
		draw_circle(cp + Vector2(4, 6), 8, Art.SHADOW)
		draw_circle(cp, 7, Color("6d7182"))
		draw_line(cp, cp + Vector2(-26, 0), Color("6d7182"), 5.0)
		var box := Rect2(cp + Vector2(-44, -10), Vector2(30, 22))
		Art.rrect(self, Rect2(box.position + Vector2(4, 6), box.size), Art.SHADOW, 4)
		Art.rrect(self, box, Color("3a3f52"), 4, 2, Art.INK)
		draw_circle(box.get_center() + Vector2(0, 8), 6, Art.INK)
		draw_circle(box.get_center() + Vector2(0, 8), 3, Color("4a5d80"))
		draw_circle(box.position + Vector2(6, 5), 2.5, Art.RED if int(_t * 2.0) % 2 == 0 else Color("5a2020"))
		if _flash > 0.0:
			Art.glow(self, box.get_center() + Vector2(0, 10), 160, Color(1, 1, 1, _flash))
	# Конец ограничения
	var ep := Vector2(Art.ROAD_RIGHT + 24, -END_SIGN)
	draw_round_sign(ep, 20, Art.LINE_WHITE, Color("8a8f9c"), "60", Color("8a8f9c"), 15)
	for k in [-6.0, 0.0, 6.0]:
		draw_line(ep + Vector2(-13 + k, 13 + k), ep + Vector2(13 + k, -13 + k), Art.INK, 1.5, true)
