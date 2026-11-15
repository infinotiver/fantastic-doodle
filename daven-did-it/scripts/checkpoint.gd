extends Area2D

@export var enabled := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not enabled or not body is CharacterBody2D:
		return
	if Game.respawn_point == $Spawn:
		return
	Game.respawn_point = $Spawn
	print("[debug] checkpoint reached: respawn at ", $Spawn.get_path())
