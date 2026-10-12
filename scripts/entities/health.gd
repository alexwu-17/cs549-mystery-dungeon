class_name EntityHealth
extends RefCounted

signal changed(current: int, maximum: int)
signal died

var maximum: int = 1
var current: int = 1


func reset(maximum_hp: int) -> void:
	maximum = maxi(1, maximum_hp)
	current = maximum
	changed.emit(current, maximum)


func damage(amount: int) -> void:
	if current == 0 or amount <= 0:
		return
	current = maxi(0, current - amount)
	changed.emit(current, maximum)
	if current == 0:
		died.emit()


func heal(amount: int) -> int:
	if current == 0 or amount <= 0:
		return 0
	var before := current
	current = mini(maximum, current + amount)
	changed.emit(current, maximum)
	return current - before
