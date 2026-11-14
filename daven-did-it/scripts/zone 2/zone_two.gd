extends Level

@onready var game_over_label: Label = $GameOverLayer/GameOverLabel


# Called by the player's "died" signal.
func _on_player_died() -> void:
	print("[debug] game over signal received")
	game_over_label.visible = true
	await get_tree().create_timer(1.0).timeout
	respawn_player()
	game_over_label.visible = false
