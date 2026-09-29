extends Area2D

const SPARK_COUNT := 7
const SPARK_COLOR := Color(0.45, 0.85, 1.0)
const SPARK_REACH := 26.0

var _taken := false


func _ready() -> void:
	add_to_group("fertilizer")


func collect() -> void:
	if _taken:
		return
	_taken = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_burst()
	_pop_and_vanish()


func _burst() -> void:
	var parent := get_parent()
	for i in SPARK_COUNT:
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([
			Vector2(-2.0, -2.0), Vector2(2.0, -2.0),
			Vector2(2.0, 2.0), Vector2(-2.0, 2.0),
		])
		spark.color = SPARK_COLOR
		spark.position = position
		parent.add_child(spark)

		var angle := TAU * float(i) / float(SPARK_COUNT)
		var tween := spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position",
			position + Vector2.from_angle(angle) * SPARK_REACH, 0.32)
		tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.32)
		tween.tween_property(spark, "modulate:a", 0.0, 0.32)
		tween.finished.connect(spark.queue_free)


func _pop_and_vanish() -> void:
	var tween := create_tween()
	tween.tween_property($Sprite, "scale", Vector2(1.35, 0.55), 0.09)
	tween.parallel().tween_property($Sprite, "modulate:a", 0.0, 0.16)
	tween.tween_callback(queue_free)
