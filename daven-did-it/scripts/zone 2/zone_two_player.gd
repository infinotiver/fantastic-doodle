extends CharacterBody2D

const SPEED := 130.0
const GRAVITY := 980.0

# 1 = normal gravity (falls down), -1 = flipped (falls up)
var gravity_direction := 1.0


# allowGravity is custom it flips gravity for zone two nothing else.
var can_flip := false

var _was_on_bounce := false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	up_direction = Vector2.UP


func _unhandled_input(event: InputEvent) -> void:
	# ignore gravity flips during DEATH
	if Game.respawning:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE and can_flip:
		flip_gravity()


func flip_gravity() -> void:
	gravity_direction *= -1
	up_direction = Vector2.UP if gravity_direction > 0 else Vector2.DOWN
	velocity.y = 0.0
	animated_sprite_2d.flip_v = gravity_direction < 0


func _physics_process(delta: float) -> void:
	velocity.y += gravity_direction * GRAVITY * delta

	if Game.respawning:
		velocity.x = 0.0
		move_and_slide()
		return

	var direction := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	_update_animation(direction)
	move_and_slide()
	_check_tile_contacts()


func _update_animation(direction: float) -> void:
	if not is_on_floor():
		animated_sprite_2d.play("jump")
	elif direction != 0:
		animated_sprite_2d.play("run")
		animated_sprite_2d.flip_h = direction < 0
	else:
		animated_sprite_2d.play("idle")


func _tile_data_for(collision: KinematicCollision2D) -> TileData:
	var collider := collision.get_collider()
	var contact := collision.get_position() - collision.get_normal() * 4.0
	if collider is TileMapLayer:
		var layer := collider as TileMapLayer
		return layer.get_cell_tile_data(layer.local_to_map(layer.to_local(contact)))
	if collider is TileMap:
		var tile_map := collider as TileMap
		var layer_index := tile_map.get_layer_for_body_rid(collision.get_collider_rid())
		if layer_index < 0:
			return null
		return tile_map.get_cell_tile_data(layer_index, tile_map.local_to_map(tile_map.to_local(contact)))
	return null


func _check_tile_contacts() -> void:
	var on_bounce := false
	var gravity_allowed := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var tile_data := _tile_data_for(collision)
		if tile_data == null:
			continue
		if tile_data.get_custom_data("death"):
			_die()
			return
		if tile_data.get_custom_data("bounce"):
			on_bounce = true
		if tile_data.get_custom_data("allowGravity") \
				and collision.get_normal().dot(up_direction) > 0.5:
			gravity_allowed = true
	if on_bounce and not _was_on_bounce:
		flip_gravity()
	_was_on_bounce = on_bounce
	can_flip = gravity_allowed


func on_death_start() -> void:
	gravity_direction = 1.0
	up_direction = Vector2.UP
	velocity = Vector2.ZERO
	can_flip = false
	animated_sprite_2d.flip_v = false


func _die() -> void:
	if Game.respawning:
		return
	for zone in get_tree().get_nodes_in_group("killzones"):
		if zone.has_method("kill"):
			zone.kill(self)
			return
	push_warning("Player: no killzone in group 'killzones' with a kill() method.")


func respawn(target: Node2D) -> void:
	gravity_direction = 1.0
	up_direction = Vector2.UP
	velocity = Vector2.ZERO
	can_flip = false
	animated_sprite_2d.flip_v = false
	if target != null:
		global_position = target.global_position
