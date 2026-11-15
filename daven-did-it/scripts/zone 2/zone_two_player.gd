extends CharacterBody2D

const SPEED := 130.0
const GRAVITY := 980.0

# 1 = normal gravity (falls down), -1 = flipped (falls up)
var gravity_direction := 1.0

# True only while the player is standing on a floor tile whose
# "allowGravity" custom data is set. Gravity flips (spacebar) are only
# allowed then: never in mid-air, and never on unflagged floors.
var can_flip := false

var _was_on_bounce := false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	up_direction = Vector2.UP


func _unhandled_input(event: InputEvent) -> void:
	# During the killzone's death sequence the bounce-back drives the body,
	# so gravity flips are ignored.
	if Game.respawning:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE and can_flip:
		flip_gravity()


## Flips gravity to the other side and reorients the sprite.
## Used by the spacebar and by bounce pad tiles.
func flip_gravity() -> void:
	gravity_direction *= -1
	up_direction = Vector2.UP if gravity_direction > 0 else Vector2.DOWN
	velocity.y = 0.0
	animated_sprite_2d.flip_v = gravity_direction < 0


func _physics_process(delta: float) -> void:
	# Apply gravity in the current direction (always, so the death bounce's
	# hops can still land).
	velocity.y += gravity_direction * GRAVITY * delta

	# While a death sequence runs (the killzone's bounce-back), input is
	# ignored: the killzone script drives the body and the animation.
	if Game.respawning:
		velocity.x = 0.0
		move_and_slide()
		return

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


## Returns the TileData of the tile this collision actually touched, or null
## if the collider isn't a tile layer.
## We look up the tile at the contact point, nudged slightly into the surface
## along the inverted normal (get_coords_for_body_rid is unreliable because
## tiles are grouped into physics quadrants).
func _tile_data_for(collision: KinematicCollision2D) -> TileData:
	var collider := collision.get_collider()
	var contact := collision.get_position() - collision.get_normal() * 4.0
	if collider is TileMapLayer:
		# Each layer is its own node, so there's no layer index to get wrong.
		var layer := collider as TileMapLayer
		return layer.get_cell_tile_data(layer.local_to_map(layer.to_local(contact)))
	if collider is TileMap:
		# A TileMap can hold several layers (floor, background, ...). Ask
		# which layer's body was hit instead of always reading layer 0, or a
		# background layer added in front of the floor hides its tile data.
		var tile_map := collider as TileMap
		var layer_index := tile_map.get_layer_for_body_rid(collision.get_collider_rid())
		if layer_index < 0:
			return null
		return tile_map.get_cell_tile_data(layer_index, tile_map.local_to_map(tile_map.to_local(contact)))
	return null


# Contacts with special tiles: the "death" custom data kills, the "bounce"
# custom data flips gravity once per landing (bounce pad), and
# "allowGravity" marks floors where the spacebar flip is allowed.
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
		# Only floor-like contacts (normal pointing against current
		# gravity) count as "standing on" the tile, so walls and
		# ceilings don't grant the ability.
		if tile_data.get_custom_data("allowGravity") \
				and collision.get_normal().dot(up_direction) > 0.5:
			gravity_allowed = true
	# Only flip on the first frame of contact, so standing on the pad
	# doesn't machine-gun flips; stepping off and back on triggers it again.
	if on_bounce and not _was_on_bounce:
		flip_gravity()
	_was_on_bounce = on_bounce
	can_flip = gravity_allowed


## Called by the killzone at the start of the death sequence, for every
## kill trigger (spike tiles or falling out of the level). Resets the
## flipped gravity, so the flight arc and landing hops fall downward and
## settle on the floor at the spawn point.
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


## Teleports back to `target` and resets all death/gravity state.
func respawn(target: Node2D) -> void:
	gravity_direction = 1.0
	up_direction = Vector2.UP
	velocity = Vector2.ZERO
	can_flip = false
	animated_sprite_2d.flip_v = false
	if target != null:
		global_position = target.global_position
