extends Node
## global game state and manager

const SPAWN_GROUP := "spawn_points"
const DEFAULT_SPAWN := &"start"

var pending_spawn: StringName = &""

var respawn_point: Node2D

var respawning := false

signal bottles_changed(count: int)

var bottles := 0


func collect_bottle() -> void:
	bottles += 1
	bottles_changed.emit(bottles)
	
func travel_to(scene: PackedScene, spawn: StringName = DEFAULT_SPAWN) -> void:
	if scene == null:
		push_warning("Game.travel_to: no scene given.")
		return
	pending_spawn = spawn
	respawn_point = null
	respawning = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_packed.call_deferred(scene)


func find_spawn(level: Node, spawn_name: StringName = DEFAULT_SPAWN) -> Node2D:
	if level == null:
		return null
	var wanted := String(spawn_name).to_lower()
	var direct_child: Node2D = null
	var first_found: Node2D = null
	for marker in level.get_tree().get_nodes_in_group(SPAWN_GROUP):
		var node := marker as Node2D
		if node == null or not level.is_ancestor_of(node):
			continue
		if first_found == null:
			first_found = node
		if wanted != "" and String(node.name).to_lower() == wanted:
			return node
		if direct_child == null and node.get_parent() == level:
			direct_child = node
	if wanted != "" and (direct_child != null or first_found != null):
		push_warning("Game: no spawn marker named '%s' in '%s', using the default one." % [spawn_name, level.name])
	if direct_child != null:
		return direct_child
	return first_found
