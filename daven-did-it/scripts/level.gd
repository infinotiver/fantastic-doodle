class_name Level
extends Node2D
## Base script for playable scenes (zones and levels within zones).
## On load, teleports the player to the spawn marker requested by whoever
## sent them here (a portal), or to the level's default start.
## Zone scripts extend this so they only need their own logic.

@onready var player: Node2D = $Player


func _ready() -> void:
	_spawn_player()


func _spawn_player() -> void:
	if player == null:
		push_warning("Level '%s' has no Player child." % name)
		return
	var spawn := Game.find_spawn(self, Game.pending_spawn)
	if spawn != null:
		player.global_position = spawn.global_position
		# Wherever we arrive becomes the respawn point until a checkpoint
		# says otherwise.
		Game.respawn_point = spawn
	# With no spawn markers at all, leave the player where the scene places it.
	Game.pending_spawn = &""


## Teleports the player back to the level's current respawn point
## (the start marker by default, or the last checkpoint touched).
## If the player script defines respawn(target), it's called so the player
## can reset its own state; otherwise the player is just teleported.
func respawn_player() -> void:
	if player == null:
		return
	var spawn := Game.respawn_point
	if spawn == null or not is_instance_valid(spawn):
		spawn = Game.find_spawn(self)
	if spawn == null:
		return
	if player.has_method("respawn"):
		player.call("respawn", spawn)
	else:
		player.global_position = spawn.global_position
