extends Area2D
## Collectible bottle: floats and tilts gently, pops when collected.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _collected := false
var _bob: Tween
var _tilt: Tween


func _ready() -> void:
	# Random delay so bottles don't all move in lockstep.
	await get_tree().create_timer(randf() * 0.8).timeout
	if _collected:
		return

	var base_y := sprite.position.y
	_bob = create_tween().set_loops()
	_bob.tween_property(sprite, "position:y", base_y - 2.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(sprite, "position:y", base_y + 2.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tilt = create_tween().set_loops()
	_tilt.tween_property(sprite, "rotation_degrees", -6.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tilt.tween_property(sprite, "rotation_degrees", 6.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not (body is CharacterBody2D):
		return
	_collected = true
	Game.collect_bottle()  # delete this line if you haven't added the counter yet
	set_deferred("monitoring", false)

	# Stop the idle loops so they don't fight the pop animation.
	if _bob:
		_bob.kill()
	if _tilt:
		_tilt.kill()

	var pop := create_tween().set_parallel(true)
	pop.tween_property(sprite, "scale", sprite.scale * 1.6, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(sprite, "position:y", sprite.position.y - 12.0, 0.2)
	pop.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await pop.finished
	queue_free()
