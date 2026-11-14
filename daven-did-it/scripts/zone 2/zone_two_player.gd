extends CharacterBody2D

signal died

const SPEED := 130.0
const GRAVITY := 980.0

# 1 = normal gravity (falls down), -1 = flipped (falls up)
var gravity_direction := 1.0
var dead := false

<<<<<<< HEAD
=======
# True only while the player is standing on a floor tile whose
# "allowGravity" custom data is set. Gravity flips (spacebar) are only
# allowed then — never in mid-air, and never on unflagged floors.
var can_flip := false

signal died

>>>>>>> eeaedcaa817c1e7ae7a87acff7d029046af7e214
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	up_direction = Vector2.UP


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	# Spacebar flips gravity, but only while standing on a floor that
	# allows it (can_flip). Never in mid-air, never on unflagged floors.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE and can_flip:
		flip_gravity()


## Flips gravity to the other side and reorients the sprite.
## Used by the spacebar and by bounce pad tiles.
func flip_gravity() -> void:
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
	_check_tile_contacts()


func _update_animation(direction: float) -> void:
	if not is_on_floor():
		animated_sprite_2d.play("jump")
	elif direction != 0:
		animated_sprite_2d.play("run")
		animated_sprite_2d.flip_h = direction < 0
	else:
		animated_sprite_2d.play("idle")


<<<<<<< HEAD
# If the tile at a collision's contact point has its "death" custom data
# set in the TileSet, the player dies.
# We look up the tile at the contact point, nudged slightly into the surface
# along the inverted normal (get_coords_for_body_rid is unreliable because
# tiles are grouped into physics quadrants).
func _check_deadly_tiles() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var contact := collision.get_position() - collision.get_normal() * 4.0
		if _is_deadly_at(collision.get_collider(), contact):
			_die()
			return
=======
# Contacts with special tiles: the "death" custom data kills, the "bounce"
# custom data flips gravity once per landing (bounce pad).
# NOTE: we can't use get_coords_for_body_rid here — in Godot 4.7 tiles are
# grouped into physics quadrants, so it reports the quadrant's base cell,
# not the tile actually touched. Instead we look up the tile at the contact
# point, nudged slightly into the surface along the inverted normal.
func _check_tile_contacts() -> void:
	var on_bounce := false
	var gravity_allowed := false
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
			if tile_data == null:
				continue
			if tile_data.get_custom_data("death"):
				print("[debug] dying at cell ", cell)
				_die()
				return
			if tile_data.get_custom_data("bounce"):
				on_bounce = true
			# Only floor-like contacts (normal pointing against current
			# gravity) count as "standing on" the tile, so walls and
			# ceilings don't grant the ability.
			if tile_data.get_custom_data("allowGravity") \
					and collision.get_normal().dot(up_direction) > 0.5:
				gravity_allowed = true
	# Only flip on the first frame of contact, so standing on the pad
	# doesn't machine-gun flips; stepping off and back on triggers it again.
	if on_bounce and not _was_on_bounce:
		print("[debug] bounce pad touched, flipping gravity")
		flip_gravity()
	_was_on_bounce = on_bounce
	if gravity_allowed != can_flip:
		print("[debug] can_flip = ", gravity_allowed)
	can_flip = gravity_allowed


var _was_on_bounce := false
>>>>>>> eeaedcaa817c1e7ae7a87acff7d029046af7e214


func _is_deadly_at(collider: Object, contact: Vector2) -> bool:
	var data: TileData = null
	if collider is TileMapLayer:
		var layer := collider as TileMapLayer
		data = layer.get_cell_tile_data(layer.local_to_map(layer.to_local(contact)))
	elif collider is TileMap:
		# Old-style TileMap node. Delete this branch once everything is
		# converted to TileMapLayer.
		var tile_map := collider as TileMap
		data = tile_map.get_cell_tile_data(0, tile_map.local_to_map(tile_map.to_local(contact)))
	return data != null and bool(data.get_custom_data("death"))


func _die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	died.emit()


## Teleports back to `target` and resets all death/gravity state.
func respawn(target: Node2D) -> void:
	dead = false
	gravity_direction = 1.0
	up_direction = Vector2.UP
	velocity = Vector2.ZERO
	animated_sprite_2d.flip_v = false
	if target != null:
		global_position = target.global_position
