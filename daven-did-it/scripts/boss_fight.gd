extends Level
## Boss fight arena. A 20 second countdown drives a "shifting tiles" hazard:
## tiles telegraph their next spot by blinking there, then become solid at
## the new spots while the old ones vanish.
##
## While the timer is above FAST_PHASE_AT the arena holds SLOW_TILES tiles
## that blink SLOW_BLINKS times per move at a relaxed pace. Once it drops
## under, only FAST_TILES tiles remain, they blink FAST_BLINKS times and
## everything runs much faster.

## Atlas coords of the tile used for the shifting tiles (from the TileMap's
## atlas source 0, the same solid tile the arena's ground uses).
@export var shift_tile_atlas := Vector2i(1, 1)
## Remaining time under which the fight switches to its faster phase.
@export var fast_phase_at := 7.0
@export var fast_blink_at := 3.0

const ARENA_MIN := Vector2i(-18, -7)  # outer rectangle corners:
const ARENA_MAX := Vector2i(17, 7)    # (17,-7) (17,7) (-18,7) (-18,-7)

const SLOW_TILES := 20
const SLOW_BLINKS := 5
const SLOW_BLINK_SECONDS := 0.4  # how long each blink half (off/on) lasts
const SLOW_CYCLE_GAP := 0.8      # pause between moves

const FAST_TILES := 15
const FAST_BLINKS := 3
const FAST_BLINK_SECONDS := 0.15
const FAST_CYCLE_GAP := 0.2

const TILE_SIZE := 16  # tile size of the arena tileset, in pixels

@onready var tile_map: TileMap = $TileMap

## The fight's countdown. Starts at 20 seconds on load; read with time_left.
var countdown: Timer
var countdown_label: Label

var _current_cells: Array[Vector2i] = []
var _ghosts: Array[Sprite2D] = []
var _in_fast_phase := false


func _ready() -> void:
	super()
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
	hud.add_child(countdown_label)
	countdown = Timer.new()
	countdown.one_shot = true
	countdown.wait_time = 20.0
	countdown.timeout.connect(_on_countdown_finished)
	add_child(countdown)
	countdown.start()
	_run_shifts()


func _process(_delta: float) -> void:
	if countdown != null and countdown_label != null and countdown.time_left > 0.0:
		countdown_label.text = "%02d" % ceili(countdown.time_left)


## Loop that keeps relocating the shifting tiles forever, re-reading the
## phase parameters every cycle so a move picks up whichever phase the
## countdown is in when it starts.
func _run_shifts() -> void:
	while is_inside_tree() and countdown.time_left > 0.0:
		var phase := _phase_params()
		var new_cells := _pick_cells(phase.count)
		_spawn_ghosts(new_cells)
		var phase_changed := false
		for blink in phase.blinks:
			_set_ghosts_visible(false)
			await get_tree().create_timer(phase.blink_seconds).timeout
			if countdown.time_left <= 0.0:
				_clear_ghosts()
				return
			if _current_phase_stage() != phase.stage:
				_clear_ghosts()
				phase_changed = true
				break
			_set_ghosts_visible(true)
			await get_tree().create_timer(phase.blink_seconds).timeout
			if countdown.time_left <= 0.0:
				_clear_ghosts()
				return
			if _current_phase_stage() != phase.stage:
				_clear_ghosts()
				phase_changed = true
				break
		if countdown.time_left <= 0.0:
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
		print("[boss] under %.0fs: %d tiles, %d blinks, faster" % [fast_blink_at, FAST_TILES, FAST_BLINKS])
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


## Chooses `count` random free cells inside the arena rectangle. Cells that
## already hold level geometry are skipped, as is anything right on top of
## the player so tiles never appear inside them.
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
		if player != null:
			var center := _cell_center(cell)
			var player_local := tile_map.to_local(player.global_position)
			if center.distance_to(player_local) < TILE_SIZE:
				continue
		picked.append(cell)
	return picked


## Swaps the tiles over: old cells are erased and the new ones become solid
## right where they were blinking.
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


## Center of a cell in the TileMap's local space.
func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2.ONE * (TILE_SIZE / 2.0)


## Hook for whatever the boss does when time runs out. The tile shifting
## keeps running in its fast phase.
func _on_countdown_finished() -> void:
	print("[boss] countdown finished")
	_clear_ghosts()
	_show_win_message()


func _show_win_message() -> void:
	countdown_label.text = "You win!"
