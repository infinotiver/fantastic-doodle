extends Control

# this is basic welcome screen, nothing special doing cuz others are dozing off.... ahhhh
@export_file("*.tscn") var first_level: String = "res://scenes/main.tscn"

@onready var start_button: Button = $Center/VBox/StartButton


func _ready() -> void:
	Game.bottles = 0
	Game.respawning = false
	Engine.time_scale = 1.0
	start_button.grab_focus()


func _on_start_pressed() -> void:
	Game.bottles = 0
	get_tree().change_scene_to_file(first_level)
