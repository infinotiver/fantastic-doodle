extends Area2D
## Collectible (the bottles). Only the player can pick it up, so moving
## platforms or other bodies passing through don't eat it.


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	queue_free()
