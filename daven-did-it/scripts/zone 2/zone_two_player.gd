extends CharacterBody2D

const SPEED := 130.0
const GRAVITY := 980.0

# 1 = normal gravity (falls down), -1 = flipped (falls up)
var gravity_direction := 1.0

var dead := false

signal died

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	up_direction = Vector2.UP


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	# Spacebar is the only other control: flip gravity.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		gravity_direction *= -1
		up_direction = Vector2.UP if gravity_direction > 0 else Vector2.DOWN
		velocity.y = 0.0
		# Orient the sprite with the new gravity.
		animated_sprite_2d.flip_v = gravity_direction < 0


func _physics_process(delta: float) -> void:
	if dead:
		return
	# Apply gravity in the current direction.
	velocity.y += gravity_direction * GRAVITY * delta

	# A / D horizontal movement only.
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
	_check_deadly_tiles()


func _update_animation(direction: float) -> void:
	if not is_on_floor():
		animated_sprite_2d.play("jump")
	elif direction != 0:
		animated_sprite_2d.play("run")
		animated_sprite_2d.flip_h = direction < 0
	else:
		animated_sprite_2d.play("idle")


# If the tile at a collision's contact point has its "death" custom data
# set in the TileSet, the player dies.
# NOTE: we can't use get_coords_for_body_rid here — in Godot 4.7 tiles are
# grouped into physics quadrants, so it reports the quadrant's base cell,
# not the tile actually touched. Instead we look up the tile at the contact
# point, nudged slightly into the surface along the inverted normal.
func _check_deadly_tiles() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is TileMap:
			var tile_map := collider as TileMap
			var contact := collision.get_position() - collision.get_normal() * 4.0
			var cell: Vector2i = tile_map.local_to_map(tile_map.to_local(contact))
			if cell != _last_debug_cell:
				_last_debug_cell = cell
				var debug_data: TileData = tile_map.get_cell_tile_data(0, cell)
				print("[debug] contact cell ", cell, ", death flag = ", debug_data != null and debug_data.get_custom_data("death"))
			var tile_data: TileData = tile_map.get_cell_tile_data(0, cell)
			if tile_data and tile_data.get_custom_data("death"):
				print("[debug] dying at cell ", cell)
				_die()
				return


var _last_debug_cell := Vector2i(999999, 999999)  # debug only


func _die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	died.emit()
