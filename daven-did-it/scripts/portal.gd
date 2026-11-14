extends Area2D
## Reusable portal: sends the player to another scene (a different zone, or
## another level in the same zone) and places them at a named spawn marker
## in that scene. The knight just needs to walk into it.

@export var target_scene: PackedScene
## Name of the spawn marker inside the target scene to appear at.
@export var target_spawn: StringName = &"start"
@export var enabled := true

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not enabled or not body is CharacterBody2D:
		return
	if target_scene == null:
		push_warning("Portal '%s' has no target scene set." % name)
		return
	_used = true
	print("Portal '%s' -> '%s' (spawn: %s)" % [name, target_scene.resource_path, target_spawn])
	Game.travel_to(target_scene, target_spawn)
