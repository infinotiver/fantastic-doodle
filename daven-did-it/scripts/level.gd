class_name Level
extends Node2D

@onready var player: Node2D = get_node_or_null("Player") as Node2D


func _ready() -> void:
	Game.respawning = false
	Engine.time_scale = 1.0
	_spawn_player()


func _spawn_player() -> void:
	# never keep a marker from the previous level.
	Game.respawn_point = null
	if player == null:
		push_warning("Level '%s' has no Player child." % name)
		Game.pending_spawn = &""
		return
	var spawn := Game.find_spawn(self, Game.pending_spawn)
	if spawn != null:
		player.global_position = spawn.global_position
		Game.respawn_point = spawn
	else:
		push_warning("Level '%s' has no node in the 'spawn_points' group." % name)
	Game.pending_spawn = &""


# just teleports player back to current respawn point (checkpoints later)
func respawn_player() -> void:
	if player == null:
		return
	var spawn: Node2D = Game.respawn_point
	if spawn == null or not is_instance_valid(spawn):
		spawn = Game.find_spawn(self, &"")
	if spawn == null:
		return
	if player.has_method("respawn"):
		player.call("respawn", spawn)
	else:
		player.global_position = spawn.global_position
