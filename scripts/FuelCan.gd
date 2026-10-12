extends Area2D

@export var fuel_restore_amount: float = 30.0 # Сколько топлива восстанавливает канистра

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_fuel"):
			body.add_fuel(fuel_restore_amount)
		queue_free()

func _physics_process(_delta: float) -> void:
	keep_clean_outside_screen()

func keep_clean_outside_screen() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var screen_size = get_viewport_rect().size
		var zoom = camera.zoom
		var view_height = screen_size.y / zoom.y
		if global_position.y > camera.global_position.y + (view_height / 2.0) + 200.0:
			queue_free()
