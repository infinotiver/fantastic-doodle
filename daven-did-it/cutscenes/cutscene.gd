extends Control

signal finished

const FADE_TIME := 0.6
const HINT_ALPHA := 0.4
const ADVANCE_ACTION := "advance"
const BUTTON_FONT_SIZE := 36
const BUTTON_MIN_SIZE := Vector2(240, 72)
const BUTTON_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const BUTTON_HOVER_COLOR := Color(1.0, 0.75, 0.3)
@export var lines: PackedStringArray
@export var choices: PackedStringArray
@export_file("*.tscn") var next_scene: String

@onready var label: Label = $Label
@onready var hint: Label = $Hint
@onready var choice_box: HBoxContainer = $Choices

var index := -1
var waiting := false


func _ready() -> void:
	label.modulate.a = 0.0
	hint.modulate.a = 0.0
	choice_box.visible = false
	advance()


func _input(event: InputEvent) -> void:
	if waiting and event.is_action_pressed(ADVANCE_ACTION):
		advance()


func advance() -> void:
	waiting = false
	hint.modulate.a = 0.0
	if index == lines.size() - 1:
		end_sequence()
		return
	await fade_to(0.0)
	index += 1
	label.text = lines[index]
	await fade_to(1.0)
	waiting = true
	hint.modulate.a = HINT_ALPHA


func fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", alpha, FADE_TIME)
	await tween.finished


func end_sequence() -> void:
	if choices.is_empty():
		await fade_to(0.0)
		finish()
		return
	for text in choices:
		var button := Button.new()
		button.text = text
		button.flat = true
		button.custom_minimum_size = BUTTON_MIN_SIZE
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.add_theme_color_override("font_color", BUTTON_COLOR)
		button.add_theme_color_override("font_hover_color", BUTTON_HOVER_COLOR)
		button.pressed.connect(finish)
		choice_box.add_child(button)
	choice_box.visible = true


func finish() -> void:
	finished.emit()
	if not next_scene.is_empty():
		get_tree().change_scene_to_file(next_scene)
