extends Level

@onready var game_over_label: Label = $GameOverLayer/GameOverLabel


func _ready() -> void:
	super()
	game_over_label.visible = false
	# Connect here so it works even if the editor connection is missing.
	# (If you also connected "died" in the editor, remove that one.)
	if player != null and player.has_signal(&"died") \
			and not player.is_connected(&"died", _on_player_died):
		player.connect(&"died", _on_player_died)


# Called by the player's "died" signal.
func _on_player_died() -> void:
	game_over_label.visible = true
	await get_tree().create_timer(1.0).timeout
	respawn_player()
	game_over_label.visible = false
