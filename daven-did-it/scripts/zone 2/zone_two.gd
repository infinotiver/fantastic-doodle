extends Level


func _ready() -> void:
	$Player.set_mode(1)  # 1 = GRAVITY_RUN
	super()

	
