extends Node2D
## Entry point for the main scene (Zone One).

const ZONE_TWO_SCENE := "res://scenes/ZoneTwo/zone_two.tscn"

var _transitioning := false


func _ready() -> void:
	print("Main scene ready")


# Fired when the player touches the transition tile at cell (-1, 2).
func _on_zone_transition_body_entered(body: Node2D) -> void:
	if _transitioning:
		return
	# The area only listens on the player's collision layer, but double-check.
	if not body is CharacterBody2D:
		return
	_transitioning = true
	print("Transition tile touched, moving to Zone Two")
	# Deferred so we don't change the scene mid physics callback.
	get_tree().change_scene_to_file.call_deferred(ZONE_TWO_SCENE)
