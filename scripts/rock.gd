extends StaticBody2D

var _flashing := false


func _ready() -> void:
	add_to_group("rock")


func flash() -> void:
	if _flashing:
		return
	_flashing = true
	var tween := create_tween()
	tween.tween_property($Sprite, "modulate", Color(1.0, 0.45, 0.4), 0.08)
	tween.tween_property($Sprite, "modulate", Color.WHITE, 0.2)
	tween.tween_callback(func() -> void: _flashing = false)
