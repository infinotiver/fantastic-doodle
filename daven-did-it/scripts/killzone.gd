extends Area2D

@export var bounce_time: float = 0.7
@export var arc_height: float = 120.0
@export var hop_speed: float = 350.0
@export var bounce_count: int = 2
@onready var timer: Timer = $Timer

var player: CharacterBody2D


func _on_body_entered(body: Node2D) -> void:
	# Ignore non-players and anything touching while a bounce is running
	# (this or any other killzone).
	if Game.respawning or not (body is CharacterBody2D):
		return
	Game.respawning = true
	player = body as CharacterBody2D
	Engine.time_scale = 0.5
	timer.start()


func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	_bounce_back()


func _bounce_back() -> void:
	# The level's start marker by default; checkpoints move this as the
	# player touches them.
	var spawn: Node2D = Game.respawn_point
	if spawn == null or not is_instance_valid(spawn):
		spawn = Game.find_spawn(get_tree().current_scene, &"")
	if spawn == null:
		push_warning("Killzone: no spawn marker in level, reloading scene instead.")
		Game.respawning = false
		get_tree().reload_current_scene()
		return

	var p := player
	var sprite: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	var base_scale := sprite.scale

	var old_layer := p.collision_layer
	var old_mask := p.collision_mask
	p.collision_layer = 0
	p.collision_mask = 0
	p.velocity = Vector2.ZERO
	p.set_physics_process(false)
	# The player's own script is paused, so pick the animation ourselves.
	sprite.play("jump")

	var start := p.global_position
	var end := spawn.global_position

	# Flight: arc to the spawn point (no overshoot)
	var move := create_tween()
	move.tween_method(func(t: float) -> void:
		var pos := start.lerp(end, t)
		pos.y -= sin(t * PI) * arc_height
		p.global_position = pos
	, 0.0, 1.0, bounce_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Squash before launch, stretch during flight
	var fly := create_tween()
	fly.tween_property(sprite, "scale", base_scale * Vector2(1.3, 0.7), bounce_time * 0.15)
	fly.tween_property(sprite, "scale", base_scale * Vector2(0.8, 1.3), bounce_time * 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await move.finished

	# Turn collision and physics back on, so the floor takes over from here
	p.collision_layer = old_layer
	p.collision_mask = old_mask
	p.set_physics_process(true)

	# Real bounces on the spawn spot, each weaker than the last
	for i in bounce_count:
		p.velocity = Vector2(0, -hop_speed * pow(0.5, i))
		_tween_scale(sprite, base_scale * Vector2(0.85, 1.25), 0.1)
		await _wait_for_landing(p)
		_tween_scale(sprite, base_scale * Vector2(1.3, 0.7), 0.08)
		await get_tree().create_timer(0.08).timeout

	# Settle
	var settle := create_tween()
	settle.tween_property(sprite, "scale", base_scale, 0.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await settle.finished

	sprite.scale = base_scale
	player = null
	Game.respawning = false


func _tween_scale(sprite: Node2D, target: Vector2, time: float) -> void:
	create_tween().tween_property(sprite, "scale", target, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _wait_for_landing(p: CharacterBody2D) -> void:
	# Two frames so is_on_floor() reflects the new upward velocity, not the old state
	await get_tree().physics_frame
	await get_tree().physics_frame
	var frames := 0
	while not p.is_on_floor() and frames < 120:  # 120 is a safety cap
		await get_tree().physics_frame
		frames += 1
