extends Node
## global game state, shared across scenes. Registered as the "Game" autoload.

const SPAWN_GROUP := "spawn_points"
const DEFAULT_SPAWN := &"start"

## Name of the spawn marker to place the player at when the next level loads.
## Portals set this before changing the scene; the level clears it on load.
var pending_spawn: StringName = &""

## Where the player respawns in the current level. Set to the level's start
## marker on load, and updated by checkpoints as they're touched.
var respawn_point: Node2D

## True while a death sequence (killzone bounce-back) is running. Shared so
## two killzones touching the player at the same time can't both start a
## bounce, and so player scripts can lock out input for the whole sequence.
var respawning := false


## Sends the player to another scene (another zone or another level within
## the same zone) and places them at the spawn marker called `spawn` there.
func travel_to(scene: PackedScene, spawn: StringName = DEFAULT_SPAWN) -> void:
	if scene == null:
		push_warning("Game.travel_to: no scene given.")
		return
	pending_spawn = spawn
	# The old level's markers are about to be freed, so drop the reference.
	respawn_point = null
	respawning = false
	Engine.time_scale = 1.0
	# Deferred so we don't change the scene mid physics callback.
	get_tree().change_scene_to_packed.call_deferred(scene)


## Finds a spawn marker inside `level`. Resolution order:
## 1. A marker whose name matches `spawn_name` (case-insensitive).
## 2. The first spawn marker that is a direct child of the level.
## 3. The first spawn marker anywhere in the level's tree.
## Pass an empty `spawn_name` to get the level's default start.
## Returns null when the level has no spawn markers at all.
## Markers must be in the "spawn_points" group.
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
