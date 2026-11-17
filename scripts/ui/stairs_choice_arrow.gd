extends Control
## A tiny stepped arrow with a horizontal-axis-style turn; no imported font glyph.
var phase: float = 0.0
func _ready() -> void:
 custom_minimum_size = Vector2(24,24)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
 phase += delta * 2.5
 queue_redraw()
func _draw() -> void:
 var squash := maxf(0.25, absf(cos(phase)))
 for row in range(9):
  var width := (5 - absi(row-4)) * 3.0
  draw_rect(Rect2(Vector2(5,12 + (row-4)*2*squash),Vector2(width,2*squash)),Color(0.9,0.95,1.0))
