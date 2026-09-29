extends SceneTree

const SCREEN_W := 640.0
const ROCK_W := 39.0
const SOIL_Y := 144.0
const ROCK_START_Y := 400.0
const ROCK_END_Y := 24000.0
const FERT_ROW_BAND := 40.0
const ROCK_COUNT_MIN := 200
const ROCK_COUNT_MAX := 2000
const SAFE_OPENING_BELOW_SOIL := 100.0
const ROCK_Y_JITTER := 34.0
const ROCK_H := 16.0
const MIN_PASSABLE_GAP := 34.0
const SWEEP_STEP := 8.0

var _did_work := false


func _process(_delta: float) -> bool:
	if _did_work:
		return false
	_did_work = true

	var packed_scene := load("res://Main.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)

	var rocks: Array[Node] = get_nodes_in_group("rock")
	var ferts: Array[Node] = get_nodes_in_group("fertilizer")
	var failures := 0
	failures += _check_counts(rocks, ferts)
	failures += _check_fixed_rock_bounds(rocks)
	failures += _check_early_clearance(rocks)
	failures += _check_corridor(rocks)
	failures += _check_density_ramp(rocks)

	if failures == 0:
		print("RESULT: PASS")
	else:
		print("RESULT: FAIL (%d checks failed)" % failures)
	quit(0 if failures == 0 else 1)
	return true


func _check_counts(rocks: Array[Node], ferts: Array[Node]) -> int:
	print("rocks=%d ferts=%d" % [rocks.size(), ferts.size()])
	var failures := 0
	if rocks.size() < ROCK_COUNT_MIN or rocks.size() > ROCK_COUNT_MAX:
		push_error("Expected %d-%d rocks, found %d" % [ROCK_COUNT_MIN, ROCK_COUNT_MAX, rocks.size()])
		failures += 1
	if ferts.is_empty():
		push_error("Course has no fertilizer pickups")
		failures += 1
	return failures


func _check_fixed_rock_bounds(rocks: Array[Node]) -> int:
	var failures := 0
	for rock in rocks:
		if rock.position.x < ROCK_W * 0.5 or rock.position.x > SCREEN_W - ROCK_W * 0.5:
			push_error("Rock is outside horizontal bounds: %s" % rock.position)
			failures += 1
		if rock.position.y < ROCK_START_Y - ROCK_Y_JITTER or rock.position.y > ROCK_END_Y + ROCK_Y_JITTER:
			push_error("Rock is outside fixed course bounds: %s" % rock.position)
			failures += 1
	print("fixed_rock_bounds=%d..%d" % [ROCK_START_Y, ROCK_END_Y])
	return failures


func _check_early_clearance(rocks: Array[Node]) -> int:
	var first_rock_y := INF
	for rock in rocks:
		first_rock_y = minf(first_rock_y, rock.position.y)

	var minimum_y := SOIL_Y + SAFE_OPENING_BELOW_SOIL
	print("first_rock_y=%.1f; required >= %.1f" % [first_rock_y, minimum_y])
	if first_rock_y < minimum_y:
		push_error("A rock is placed within the first 100px below the soil")
		return 1
	return 0


func _check_course_spacing(rocks: Array[Node]) -> int:
	var ys: Array[float] = []
	for rock in rocks:
		ys.append(rock.position.y)
	ys.sort()
	var min_spacing := INF
	for i in range(1, ys.size()):
		min_spacing = minf(min_spacing, ys[i] - ys[i - 1])
	print("minimum_vertical_rock_spacing=%.1f px" % min_spacing)
	if min_spacing < FERT_ROW_BAND:
		push_error("Fixed rocks are unexpectedly clustered vertically")
		return 1
	return 0


func _check_corridor(rocks: Array[Node]) -> int:
	var half_w := ROCK_W * 0.5
	var half_h := ROCK_H * 0.5
	var tightest := 99999.0
	var tightest_y := 0.0
	var blocked := 0

	var y := ROCK_START_Y
	while y < ROCK_END_Y:
		var blockers: Array[float] = []
		for r in rocks:
			if absf(r.position.y - y) <= half_h:
				blockers.append(r.position.x)
		blockers.sort()

		var widest := 0.0
		var edge := 0.0
		for bx in blockers:
			widest = maxf(widest, bx - half_w - edge)
			edge = bx + half_w
		widest = maxf(widest, SCREEN_W - edge)

		if widest < tightest:
			tightest = widest
			tightest_y = y
		if widest < MIN_PASSABLE_GAP:
			blocked += 1
		y += SWEEP_STEP

	print("corridor_sweep: tightest_gap=%.1f px at y=%.0f, blocked_heights=%d"
		% [tightest, tightest_y, blocked])
	if blocked > 0:
		push_error("%d heights have no passable opening (< %.0f px)"
			% [blocked, MIN_PASSABLE_GAP])
		return 1
	return 0


func _check_density_ramp(rocks: Array[Node]) -> int:
	var bands := [
		[400.0, 3000.0], [3000.0, 8000.0],
		[8000.0, 15000.0], [15000.0, 24000.0],
	]
	var per_meter := []
	for b in bands:
		var n := 0
		var lo: float = b[0]
		var hi: float = b[1]
		for r in rocks:
			if r.position.y >= lo and r.position.y < hi:
				n += 1
		var span_m: float = (hi - lo) / 250.0
		var pm: float = float(n) / maxf(span_m, 1.0)
		per_meter.append(pm)
		print("band %d-%d: %d rocks (%.2f/m)" % [int(lo), int(hi), n, pm])

	if per_meter[3] <= per_meter[0]:
		push_error("Density did not increase with depth")
		return 1
	return 0
