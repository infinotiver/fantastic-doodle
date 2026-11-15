extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Game.respawning:
		velocity.x = 0.0
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")

	if direction > 0:
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		animated_sprite_2d.flip_h = true

	# Move horizontallyyyy
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	_update_animation(direction)
	move_and_slide()
	_check_killboxes()


func _check_killboxes() -> void:

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var tilemap := collision.get_collider() as TileMap
		if tilemap == null:
			continue
		var contact := collision.get_position() - collision.get_normal() * 4.0
		var cell: Vector2i = tilemap.local_to_map(tilemap.to_local(contact))
		for layer in tilemap.get_layers_count():
			var data := tilemap.get_cell_tile_data(layer, cell)
			if data != null and data.get_custom_data("killbox"):
				_die()
				return


func _die() -> void:
	for zone in get_tree().get_nodes_in_group("killzones"):
		if zone.has_method("kill"):
			zone.kill(self)
			return


func _update_animation(direction: float) -> void:
	if not is_on_floor():
		animated_sprite_2d.play("jump")
	elif direction != 0:
		animated_sprite_2d.play("run")
	else:
		animated_sprite_2d.play("idle")
