extends Area2D
@export_file("*.tscn") var target_scene_path: String
@export var target_spawn: StringName = &"start"
@export var enabled := true

var _used := false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not enabled or not (body is CharacterBody2D):
		return
	if target_scene_path.is_empty():
		push_warning("Portal '%s' has no target scene set." % name)
		return
	var scene := load(target_scene_path) as PackedScene
	if scene == null:
		push_warning("Portal '%s' could not load '%s'." % [name, target_scene_path])
		return
	_used = true
	Game.travel_to(scene, target_spawn)
