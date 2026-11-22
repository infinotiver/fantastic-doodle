extends CharacterBody2D

enum Mode { PLATFORMER, GRAVITY_RUN }

const SPEED := 130.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 980.0

@export var mode: Mode = Mode.PLATFORMER
@export var run_direction := 1.0  # +1 = right, -1 = left (gravity run only)

# 1 = falls down, -1 = falls up (gravity run only)
var gravity_direction := 1.0
var can_flip := false
var _was_on_bounce := false

@export var run_speed := 60.0        # starting speed in zone two
@export var max_run_speed := 130.0   # set equal to run_speed for constant slow speed
@export var run_accel := 40.0

var _current_run_speed := 60.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	set_mode(mode)



func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_reset_gravity()
	_was_on_bounce = false
	_current_run_speed = run_speed
	if mode == Mode.GRAVITY_RUN:
		animated_sprite_2d.flip_h = run_direction < 0

func _reset_gravity() -> void:
	gravity_direction = 1.0
	up_direction = Vector2.UP
	velocity = Vector2.ZERO
	can_flip = false
	animated_sprite_2d.flip_v = false


# zone two input
func _unhandled_input(event: InputEvent) -> void:
	if Game.respawning or mode != Mode.GRAVITY_RUN:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE and can_flip:
		flip_gravity()


func flip_gravity() -> void:
	gravity_direction *= -1.0
	up_direction = Vector2.UP if gravity_direction > 0 else Vector2.DOWN
	velocity.y = 0.0
	animated_sprite_2d.flip_v = gravity_direction < 0


# ---------- physics ----------
func _physics_process(delta: float) -> void:
	if mode == Mode.PLATFORMER:
		_platformer_step(delta)
	else:
		_gravity_run_step(delta)


func _platformer_step(delta: float) -> void:
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

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	_update_animation(direction)
	move_and_slide()
	_check_tile_contacts()


func _gravity_run_step(delta: float) -> void:
	velocity.y += gravity_direction * GRAVITY * delta

	if Game.respawning:
		velocity.x = 0.0
		move_and_slide()
		return

	_current_run_speed = move_toward(_current_run_speed, max_run_speed, run_accel * delta)
	velocity.x = run_direction * _current_run_speed

	_update_animation(run_direction)
	move_and_slide()
	_check_tile_contacts()


func _update_animation(direction: float) -> void:
	if not is_on_floor():
		animated_sprite_2d.play("jump")
	elif direction != 0:
		animated_sprite_2d.play("run")
	else:
		animated_sprite_2d.play("idle")


# tiles
func _tile_info_for(collision: KinematicCollision2D) -> Dictionary:
	var collider := collision.get_collider()
	var contact := collision.get_position() - collision.get_normal() * 4.0
	if collider is TileMapLayer:
		var layer := collider as TileMapLayer
		return {
			"data": layer.get_cell_tile_data(layer.local_to_map(layer.to_local(contact))),
			"tile_set": layer.tile_set,
		}
	if collider is TileMap:
		var tile_map := collider as TileMap
		var layer_index := tile_map.get_layer_for_body_rid(collision.get_collider_rid())
		if layer_index < 0:
			return {}
		return {
			"data": tile_map.get_cell_tile_data(layer_index, tile_map.local_to_map(tile_map.to_local(contact))),
			"tile_set": tile_map.tile_set,
		}
	return {}


# Safe read: returns false if the tileset doesn't have that custom data layer
func _flag(tile_set: TileSet, data: TileData, flag_name: String) -> bool:
	if tile_set == null or data == null:
		return false
	if tile_set.get_custom_data_layer_by_name(flag_name) < 0:
		return false
	return bool(data.get_custom_data(flag_name))


func _check_tile_contacts() -> void:
	var on_bounce := false
	var gravity_allowed := false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var info := _tile_info_for(collision)
		if info.is_empty() or info["data"] == null:
			continue
		var data: TileData = info["data"]
		var ts: TileSet = info["tile_set"]

		if _flag(ts, data, "death") or _flag(ts, data, "killbox"):
			_die()
			return

		if mode == Mode.GRAVITY_RUN:
			if on_bounce and not _was_on_bounce:
				flip_gravity()
			_was_on_bounce = on_bounce
			can_flip = gravity_allowed

# death and respawn
func on_death_start() -> void:
	_reset_gravity()


func _die() -> void:
	if Game.respawning:
		return
	for zone in get_tree().get_nodes_in_group("killzones"):
		if zone.has_method("kill"):
			zone.kill(self)
			return
	push_warning("Player: no killzone in group 'killzones' with a kill() method.")


func respawn(target: Node2D) -> void:
	_reset_gravity()
	if target != null:
		global_position = target.global_position
