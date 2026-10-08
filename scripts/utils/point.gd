class_name Point
var x: int = 0;
var y: int = 0;

func _init(x_: int, y_: int):
	self.x = x_;
	self.y = y_;


func _to_string():
	var format_string := "(x, y) = (%d, %d)" % [self.x, self.y];
	return format_string;
