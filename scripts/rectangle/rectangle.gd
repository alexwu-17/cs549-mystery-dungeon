class_name Rectangle
var x: int = 0
var y: int = 0
var w: int = 0
var h: int = 0


func _init(x_: int, y_: int, w_: int, h_: int):
	self.x = x_;
	self.y = y_;
	self.w = w_;
	self.h = h_;


func _to_string():
	var format_string := "(x, y, w, h) = (%d, %d, %d, %d)" % [self.x, self.y, self.w, self.h];
	return format_string;


static func overlaps(a: Rectangle, b: Rectangle, padding: int = 1) -> bool:
	return not(
			a.x + a.w + padding <= b.x 
			or b.x + b.w + padding <= a.x 
			or a.y + a.h + padding <= b.y 
			or b.y + b.h + padding <= a.y
	);
