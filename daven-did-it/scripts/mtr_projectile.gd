extends Area2D

@export var fall_speed := 160.0


func _physics_process(delta: float) -> void:
	global_position.y += fall_speed * delta
	if global_position.y > 500.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	var tile_map := body as TileMap
	if tile_map == null:
		return
	var impact_position := tile_map.to_local(global_position)
	var impact_cell := tile_map.local_to_map(impact_position)
	var nearest_cell := Vector2i.ZERO
	var nearest_distance := INF
	var found_tile := false
	for x in range(impact_cell.x - 1, impact_cell.x + 2):
		for y in range(impact_cell.y - 1, impact_cell.y + 2):
			var cell := Vector2i(x, y)
			if tile_map.get_cell_source_id(0, cell) == -1:
				continue
			var distance := impact_position.distance_to(tile_map.map_to_local(cell))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_cell = cell
				found_tile = true
	if found_tile:
		tile_map.erase_cell(0, nearest_cell)
	queue_free()
