extends Area2D

@export var new_mode: Player.Mode  # or just use 1 for GRAVITY_RUN

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_mode"):
		body.set_mode(1)  # 0 = PLATFORMER, 1 = GRAVITY_RUN
