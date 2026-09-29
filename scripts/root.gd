extends Node2D

signal crossed_own_path

const TEXTURE := preload("res://art/root.png")

const SPEED := 100.0
const TURN_RATE := 120.0
const SEGMENT_GAP := 5.0
const MAX_SEGMENTS := 1000
const FACING_OFFSET := 90.0

const HIT_RADIUS := 10.0
const RECENT_SKIP := 45.0
const MIN_LENGTH := 150.0
const SAMPLE_GAP := 5.0
const CELL := 20.0

var current_angle := PI / 2.0
var target_angle := PI / 2.0
var tip_position := Vector2.ZERO
var active := true
var speed_scale := 1.0

var _points: Array[Vector2] = []
var _distances := PackedFloat32Array()
var _cells := {}
var _length := 0.0
var _sampled_at := 0.0
var _previous_tip := Vector2.ZERO
var _drawn_to := Vector2.ZERO

@onready var trail: Node2D = $Trail
@onready var tip: Sprite2D = $Tip


func start(at: Vector2, heading: float) -> void:
	current_angle = heading
	target_angle = heading
	tip_position = at
	active = true
	speed_scale = 1.0

	for child in trail.get_children():
		child.queue_free()

	_drawn_to = at
	_points = [at]
	_distances = [0.0]
	_cells = {}
	_length = 0.0
	_sampled_at = 0.0
	_previous_tip = at
	_hash(at)

	_sync()


func _process(delta: float) -> void:
	if not active:
		return

	var to_cursor := get_local_mouse_position() - tip_position
	if to_cursor.length() > 1.0:
		target_angle = to_cursor.angle()

	advance(delta)


func advance(delta: float) -> void:
	current_angle = rotate_toward(current_angle, target_angle, deg_to_rad(TURN_RATE) * delta)
	tip_position += Vector2.from_angle(current_angle) * SPEED * speed_scale * delta

	_sample_path()
	_sync()

	if _hit_own_path():
		active = false
		crossed_own_path.emit()


func _sync() -> void:
	tip.position = tip_position
	tip.rotation = current_angle + deg_to_rad(FACING_OFFSET)

	if _drawn_to.distance_to(tip_position) < SEGMENT_GAP:
		return

	var span := _drawn_to.distance_to(tip_position)
	var count := int(span / SEGMENT_GAP)
	for i in range(1, count + 1):
		var at := _drawn_to.lerp(tip_position, float(i) * SEGMENT_GAP / span)
		var segment := Sprite2D.new()
		segment.texture = TEXTURE
		segment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		segment.position = at
		segment.rotation = current_angle + deg_to_rad(FACING_OFFSET)
		trail.add_child(segment)

	var drawn := trail.get_child_count()
	while drawn > MAX_SEGMENTS:
		trail.get_child(0).queue_free()
		drawn -= 1

	_drawn_to = tip_position


func _sample_path() -> void:
	_length += _previous_tip.distance_to(tip_position)
	_previous_tip = tip_position

	if _length - _sampled_at < SAMPLE_GAP:
		return

	_sampled_at = _length
	_points.append(tip_position)
	_distances.append(_length)
	_hash(tip_position)


func _hash(at: Vector2) -> void:
	var key := _cell_of(at)
	var bucket: PackedInt32Array = _cells.get(key, PackedInt32Array())
	bucket.append(_points.size() - 1)
	_cells[key] = bucket


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.y / CELL))


func _hit_own_path() -> bool:
	if _length < MIN_LENGTH:
		return false

	var newest := _points.size() - 1
	if newest < 1:
		return false

	var cutoff := _length - RECENT_SKIP
	var home := _cell_of(tip_position)

	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var bucket: PackedInt32Array = _cells.get(home + Vector2i(ox, oy), PackedInt32Array())
			for i in bucket:
				if i < newest and _distances[i] <= cutoff:
					if _points[i].distance_to(tip_position) <= HIT_RADIUS:
						return true
	return false
