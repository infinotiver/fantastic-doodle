extends Level

@export var shift_tile_atlas := Vector2i(1, 1)

@export var bottle_scene: PackedScene = preload("res://scenes/bottle.tscn")
@export var bottles_to_win := 5
@export var start_seconds := 30.0
@export var bonus_seconds := 4.0
@export var calm_seconds := 2.5
@export_file("*.tscn") var next_scene: String = "res://scenes/main_menu.tscn"
const HUD_FONT_B = preload("res://assets/fonts/PixelifySans-Bold.ttf")
@export var fast_phase_at := 7.0
@export var fast_blink_at := 3.0

const ARENA_MIN := Vector2i(-18, -7)
const ARENA_MAX := Vector2i(17, 7)

const SLOW_TILES := 20
const SLOW_BLINKS := 5
const SLOW_BLINK_SECONDS := 0.4
const SLOW_CYCLE_GAP := 0.8

const FAST_TILES := 15
const FAST_BLINKS := 3
const FAST_BLINK_SECONDS := 0.15
const FAST_CYCLE_GAP := 0.2

const MTR_1_SCENE: PackedScene = preload("res://mtr_1.tscn")
const MTR_2_SCENE: PackedScene = preload("res://mtr_2.tscn")
const MTR_SPAWN_INTERVAL := 0.2
const FALL_KILLZONE_POSITION := Vector2(0, 176)
const FALL_KILLZONE_SIZE := Vector2(1200, 24)

const TILE_SIZE := 16

@onready var tile_map: TileMap = $TileMap
@onready var daven: Node2D = $DAVEN

var countdown: Timer
var countdown_label: Label
var hp_bar: ProgressBar
var hint_label: Label

var _current_cells: Array[Vector2i] = []
var _ghosts: Array[Sprite2D] = []
var _in_fast_phase := false
var _game_over := false
var _bottles_left := 0
var _bottle: Node2D
var _bottle_cell := Vector2i.ZERO
var _calm_until := 0.0


func _ready() -> void:
	super()
	_bottles_left = bottles_to_win
	_create_fall_killzone()

	var hud := CanvasLayer.new()
	add_child(hud)

	countdown_label = Label.new()
	countdown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	countdown_label.position = Vector2(-130, 16)
	countdown_label.size = Vector2(260, 48)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 36)
	countdown_label.add_theme_color_override("font_color", Color.WHITE)
	countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	countdown_label.add_theme_constant_override("outline_size", 6)
	countdown_label.add_theme_font_override("font", HUD_FONT_B)
	hud.add_child(countdown_label)

	hp_bar = ProgressBar.new()
	hp_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hp_bar.position = Vector2(-130, 66)
	hp_bar.size = Vector2(260, 14)
	hp_bar.max_value = bottles_to_win
	hp_bar.value = bottles_to_win
	hp_bar.show_percentage = false
	hud.add_child(hp_bar)

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_label.position = Vector2(-250, 88)
	hint_label.size = Vector2(500, 28)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 5)
	hint_label.text = "Grab the bottles to break Daven's courage!"
	hud.add_child(hint_label)
	create_tween().tween_property(hint_label, "modulate:a", 0.0, 1.0).set_delay(5.0)

	countdown = Timer.new()
	countdown.one_shot = true
	countdown.wait_time = start_seconds
	countdown.timeout.connect(_on_countdown_finished)
	add_child(countdown)
	countdown.start()

	Game.bottles_changed.connect(_on_bottle_collected)
	_spawn_bottle()
	_run_mtr_shower()
	_run_shifts()


func _process(_delta: float) -> void:
	if _game_over:
		return
	if countdown != null and countdown_label != null and countdown.time_left > 0.0:
		countdown_label.text = "%02d" % ceili(countdown.time_left)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _run_mtr_shower() -> void:
	var scenes: Array[PackedScene] = [MTR_1_SCENE, MTR_2_SCENE]
	var scene_index := 0
	while is_inside_tree() and not _game_over and countdown.time_left > 0.0:
		if _now() < _calm_until:
			await get_tree().create_timer(0.1).timeout
			continue
		var projectile := scenes[scene_index].instantiate() as Area2D
		projectile.add_to_group("boss_projectiles")
		add_child(projectile)
		var x := randi_range(ARENA_MIN.x, ARENA_MAX.x)
		projectile.global_position = tile_map.to_global(_cell_center(Vector2i(x, ARENA_MIN.y - 2)))
		scene_index = (scene_index + 1) % scenes.size()
		await get_tree().create_timer(MTR_SPAWN_INTERVAL).timeout


func _run_shifts() -> void:
	while is_inside_tree() and not _game_over and countdown.time_left > 0.0:
		var phase := _phase_params()
		var new_cells := _pick_cells(phase.count)
		_spawn_ghosts(new_cells)
		var phase_changed := false
		for blink in phase.blinks:
			_set_ghosts_visible(false)
			await get_tree().create_timer(phase.blink_seconds).timeout
			if _game_over or countdown.time_left <= 0.0:
				_clear_ghosts()
				return
			if _current_phase_stage() != phase.stage:
				_clear_ghosts()
				phase_changed = true
				break
			_set_ghosts_visible(true)
			await get_tree().create_timer(phase.blink_seconds).timeout
			if _game_over or countdown.time_left <= 0.0:
				_clear_ghosts()
				return
			if _current_phase_stage() != phase.stage:
				_clear_ghosts()
				phase_changed = true
				break
		if _game_over or countdown.time_left <= 0.0:
			_clear_ghosts()
			return
		if phase_changed:
			continue
		_move_tiles(new_cells)
		await get_tree().create_timer(phase.cycle_gap).timeout


func _phase_params() -> Dictionary:
	var stage := _current_phase_stage()
	var fast_blinking := stage == 2
	if fast_blinking and not _in_fast_phase:
		_in_fast_phase = true
	elif not fast_blinking:
		_in_fast_phase = false
	if stage > 0:
		return {
			"stage": stage,
			"count": FAST_TILES,
			"blinks": FAST_BLINKS,
			"blink_seconds": FAST_BLINK_SECONDS if fast_blinking else SLOW_BLINK_SECONDS,
			"cycle_gap": FAST_CYCLE_GAP if fast_blinking else SLOW_CYCLE_GAP,
		}
	return {
		"stage": stage,
		"count": SLOW_TILES,
		"blinks": SLOW_BLINKS,
		"blink_seconds": SLOW_BLINK_SECONDS,
		"cycle_gap": SLOW_CYCLE_GAP,
	}


func _current_phase_stage() -> int:
	if countdown.time_left <= fast_blink_at:
		return 2
	if countdown.time_left < fast_phase_at:
		return 1
	return 0


func _pick_cells(count: int) -> Array[Vector2i]:
	var picked: Array[Vector2i] = []
	var attempts := 0
	while picked.size() < count and attempts < count * 20:
		attempts += 1
		var cell := Vector2i(
			randi_range(ARENA_MIN.x, ARENA_MAX.x),
			randi_range(ARENA_MIN.y, ARENA_MAX.y))
		if cell in picked:
			continue
		if tile_map.get_cell_source_id(0, cell) != -1:
			continue
		if is_instance_valid(_bottle) and cell == _bottle_cell:
			continue
		if player != null:
			var center := _cell_center(cell)
			var player_local := tile_map.to_local(player.global_position)
			if center.distance_to(player_local) < TILE_SIZE:
				continue
		picked.append(cell)
	return picked


func _move_tiles(new_cells: Array[Vector2i]) -> void:
	for cell in _current_cells:
		tile_map.erase_cell(0, cell)
	_current_cells = new_cells
	for cell in new_cells:
		tile_map.set_cell(0, cell, 0, shift_tile_atlas)
	_clear_ghosts()


func _spawn_ghosts(cells: Array[Vector2i]) -> void:
	_clear_ghosts()
	var source := tile_map.tile_set.get_source(0) as TileSetAtlasSource
	for cell in cells:
		var ghost := Sprite2D.new()
		ghost.texture = source.texture
		ghost.region_enabled = true
		ghost.region_rect = Rect2(
			shift_tile_atlas.x * TILE_SIZE, shift_tile_atlas.y * TILE_SIZE,
			TILE_SIZE, TILE_SIZE)
		ghost.position = _cell_center(cell)
		tile_map.add_child(ghost)
		_ghosts.append(ghost)


func _set_ghosts_visible(visible_now: bool) -> void:
	for ghost in _ghosts:
		ghost.visible = visible_now


func _clear_ghosts() -> void:
	for ghost in _ghosts:
		ghost.queue_free()
	_ghosts.clear()


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)


func _spawn_bottle() -> void:
	if _game_over:
		return
	if bottle_scene == null:
		push_warning("BossFight: no Bottle Scene assigned.")
		return
	if is_instance_valid(_bottle):
		return
	var player_local := Vector2.ZERO
	if player != null:
		player_local = tile_map.to_local(player.global_position)
	var spots: Array[Vector2i] = []
	for x in range(ARENA_MIN.x, ARENA_MAX.x + 1):
		for y in range(ARENA_MIN.y, ARENA_MAX.y + 1):
			var spot := Vector2i(x, y)
			if tile_map.get_cell_source_id(0, spot) != -1:
				continue
			var below := spot + Vector2i.DOWN
			if tile_map.get_cell_source_id(0, below) == -1:
				continue
			if below in _current_cells:
				continue
			if _cell_center(spot).distance_to(player_local) < TILE_SIZE * 4:
				continue
			spots.append(spot)
	if spots.is_empty():
		return
	_bottle_cell = spots.pick_random()
	_bottle = bottle_scene.instantiate() as Node2D
	add_child(_bottle)
	_bottle.global_position = tile_map.to_global(_cell_center(_bottle_cell))


func _on_bottle_collected(_total: int) -> void:
	if _game_over:
		return
	_bottle = null
	_bottles_left -= 1
	hp_bar.value = _bottles_left
	countdown.start(countdown.time_left + bonus_seconds)
	_calm_until = _now() + calm_seconds
	for projectile in get_tree().get_nodes_in_group("boss_projectiles"):
		projectile.queue_free()
	_hit_daven()
	if _bottles_left <= 0:
		_win()
	else:
		await get_tree().create_timer(1.0).timeout
		_spawn_bottle()


func _hit_daven() -> void:
	var base_pos := daven.position
	var flash := create_tween()
	flash.tween_property(daven, "modulate", Color(1.0, 0.3, 0.3), 0.08)
	flash.tween_property(daven, "modulate", Color.WHITE, 0.25)
	var shake := create_tween()
	for i in 4:
		shake.tween_property(daven, "position:x", base_pos.x + (6.0 if i % 2 == 0 else -6.0), 0.05)
	shake.tween_property(daven, "position", base_pos, 0.05)


func _win() -> void:
	_game_over = true
	countdown.stop()
	_clear_ghosts()
	for projectile in get_tree().get_nodes_in_group("boss_projectiles"):
		projectile.queue_free()
	countdown_label.text = "Daven is defeated!"
	hint_label.modulate.a = 1.0
	hint_label.text = "The Knight's Kingdom Returns."
	var t := create_tween().set_parallel(true)
	t.tween_property(daven, "rotation", TAU * 2.0, 0.9)
	t.tween_property(daven, "scale", Vector2.ZERO, 0.9)
	t.tween_property(daven, "modulate:a", 0.0, 0.9)
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file(next_scene)


func _create_fall_killzone() -> void:
	var killzone := Area2D.new()
	killzone.name = "FallKillzone"
	killzone.collision_layer = 0
	killzone.collision_mask = 2
	killzone.position = FALL_KILLZONE_POSITION
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = FALL_KILLZONE_SIZE
	collision.shape = shape
	killzone.add_child(collision)
	add_child(killzone)
	killzone.body_entered.connect(_on_fall_killzone_body_entered)


func _on_fall_killzone_body_entered(body: Node2D) -> void:
	if body == player:
		_finish_game_over()


func _finish_game_over() -> void:
	if _game_over:
		return
	_game_over = true
	countdown.stop()
	_clear_ghosts()
	for projectile in get_tree().get_nodes_in_group("boss_projectiles"):
		projectile.queue_free()
	if player != null:
		player.set_physics_process(false)
	countdown_label.text = "Game Over!"
	hint_label.modulate.a = 1.0
	hint_label.text = "Retrying..."
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()


func _on_countdown_finished() -> void:
	_finish_game_over()
