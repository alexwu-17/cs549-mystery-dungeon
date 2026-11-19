extends "res://scripts/ui/stairs_choice_arrow.gd"

func _draw() -> void:
	var squash := maxf(0.25, absf(cos(phase)))
	for row in range(7):
		var width := (7 - row) * 3.0 * squash
		draw_rect(Rect2(Vector2(12.0 - width / 2.0, 4.0 + row * 2.0), Vector2(width, 2.0)), Color(0.9, 0.95, 1.0))
