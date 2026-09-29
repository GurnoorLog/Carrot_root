extends RefCounted

const ROCK := preload("res://Rock.tscn")
const FERTILIZER := preload("res://Fertilizer.tscn")

const SCREEN_W := 640.0
const EDGE_PAD := 6.0

const START_Y := 400.0
const END_Y := 24000.0
const SPACING_SHALLOW := 260.0
const SPACING_DEEP := 130.0
const GAP_SHALLOW := 185.0
const GAP_DEEP := 112.0
const GAP_DRIFT := 95.0
const ROCK_W := 39.0
const ROCK_HALF := 19.5
const ROCK_JITTER := 34.0
const FERTILIZER_CHANCE := 0.16


static func build(rng: RandomNumberGenerator, rocks: Node2D, pickups: Node2D) -> void:
	var y := START_Y + ROCK_JITTER
	var gap_x := SCREEN_W * 0.5
	var row := 0

	while y < END_Y:
		var depth := clampf((y - START_Y) / (END_Y - START_Y), 0.0, 1.0)
		var gap := lerpf(GAP_SHALLOW, GAP_DEEP, depth)

		var limit := EDGE_PAD + ROCK_HALF + gap * 0.5
		gap_x = clampf(gap_x + rng.randf_range(-GAP_DRIFT, GAP_DRIFT), limit, SCREEN_W - limit)

		var half := gap * 0.5
		_scatter(gap_x - half - ROCK_HALF, -1.0, y, rng, rocks)
		_scatter(gap_x + half + ROCK_HALF, 1.0, y, rng, rocks)

		if row < 3 or rng.randf() < FERTILIZER_CHANCE:
			var fert := FERTILIZER.instantiate()
			fert.position = Vector2(
				gap_x + rng.randf_range(-half * 0.4, half * 0.4),
				y + rng.randf_range(-half * 0.35, half * 0.35)
			)
			pickups.add_child(fert)

		y += lerpf(SPACING_SHALLOW, SPACING_DEEP, depth)
		row += 1


static func _scatter(x: float, dir: float, y: float, rng: RandomNumberGenerator, rocks: Node2D) -> void:
	var lo := EDGE_PAD + ROCK_HALF
	var hi := SCREEN_W - EDGE_PAD - ROCK_HALF

	while x >= lo and x <= hi:
		var rock := ROCK.instantiate()
		rock.position = Vector2(x, y + rng.randf_range(-ROCK_JITTER, ROCK_JITTER))
		rocks.add_child(rock)
		x += dir * (ROCK_W + rng.randf_range(6.0, 26.0))
