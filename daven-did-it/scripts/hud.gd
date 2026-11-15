extends CanvasLayer

@onready var panel: PanelContainer = %BottlePanel
@onready var label: Label = %BottleLabel


func _ready() -> void:
	_set_count(Game.bottles)
	Game.bottles_changed.connect(_on_bottles_changed)


func _on_bottles_changed(count: int) -> void:
	_set_count(count)
	# small pop so the player notices the change.
	panel.pivot_offset = panel.size / 2.0
	var t := create_tween()
	t.tween_property(panel, "scale", Vector2(1.15, 1.15), 0.08)
	t.tween_property(panel, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_count(count: int) -> void:
	label.text = "x %d" % count
