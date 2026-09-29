extends SceneTree

var _f := 0
var _main: Node = null
var _root: Node = null
var _fails := 0
var _self_hit := false


func _process(_delta: float) -> bool:
	_f += 1
	if _f == 1:
		_main = (load("res://Main.tscn") as PackedScene).instantiate()
		root.add_child(_main)
		_root = _main.get_node("World/Root")
		_root.crossed_own_path.connect(func(): _self_hit = true)
		return false
	if _f == 2:
		_check_tangent_spawn()
		return false
	if _f == 3:
		_step(1.0, _root.current_angle)
		_check_body_and_steering()
		return false
	if _f == 4:
		_check_crossed_own_path()
		return false
	if _f == 5:
		return _finish()
	return false


func _step(seconds: float, heading := INF) -> void:
	var step := 1.0 / 60.0
	for i in int(seconds / step):
		if heading != INF:
			_root.target_angle = heading
		_root.advance(step)


func _check_tangent_spawn() -> void:
	var tip: Vector2 = _root.tip_position
	var dir := Vector2.from_angle(_root.current_angle)
	_expect(absf(tip.x - 320.0) < 2.0, "spawns at centre x (got %.1f)" % tip.x)
	_expect(dir.x < -0.3, "original root heads left (dir.x=%.2f)" % dir.x)
	_expect(dir.y > 0.0, "original root heads down (dir.y=%.2f)" % dir.y)
	_expect(_root.active, "root starts active")
	print("spawn: tip=%s dir=(%.2f, %.2f)" % [tip, dir.x, dir.y])


func _check_body_and_steering() -> void:
	var trail = _root.get_node("Trail")
	var sprites: int = trail.get_child_count()
	_expect(sprites >= 15, "root stamped a contiguous body (%d sprites in 1s)" % sprites)
	_expect(_root.tip_position.y > 146.0, "root grew downward (y=%.1f)" % _root.tip_position.y)
	_check_overlap(trail)

	var before: float = _root.current_angle
	_step(0.5, 0.0)
	var after: float = _root.current_angle
	_expect(absf(after - before) > 0.01,
		"root turns toward a new heading (%.2f -> %.2f)" % [before, after])
	_expect(absf(after - before) <= deg_to_rad(60.0) + 0.01,
		"turn rate is capped (swept %.1f deg in 0.5s)" % rad_to_deg(absf(after - before)))
	print("body: sprites=%d turn %.2f -> %.2f" % [sprites, before, after])


func _check_overlap(trail: Node) -> void:
	var kids := trail.get_children()
	if kids.size() < 3:
		_expect(false, "not enough segments to measure overlap")
		return

	var reach: float = kids[0].texture.get_height()
	var worst := 0.0
	var worst_at := Vector2.ZERO
	for i in range(1, kids.size()):
		var gap: float = (kids[i].position - kids[i - 1].position).length()
		if gap > worst:
			worst = gap
			worst_at = kids[i].position

	_expect(worst < reach,
		"adjacent segments overlap (worst gap %.1f px vs %.0f px sprite reach)" % [worst, reach])
	print("overlap: %d segments, worst gap %.2f px, sprite reach %.0f px"
		% [kids.size(), worst, reach])


func _check_crossed_own_path() -> void:
	var heading: float = _root.current_angle
	for i in 400:
		heading += deg_to_rad(12.0)
		_step(1.0 / 60.0, heading)
	_expect(not _self_hit, "steering hard does not falsely report self-collision")
	_expect(_root.active, "root keeps growing while steering in circles")
	print("crossed_own_path=%s (expected false: turn cap keeps circles wider than the skip window)" % _self_hit)


func _finish() -> bool:
	var fresh = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(fresh)
	var fresh_root = fresh.get_node("World/Root")
	fresh_root.start(Vector2(60.0, 300.0), PI)
	for i in 240:
		fresh_root.target_angle = PI
		fresh_root.advance(1.0 / 60.0)
		fresh._process(1.0 / 60.0)

	_expect(not fresh.alive, "root driven into the wall ends the run")
	_expect(not fresh_root.active, "root stops growing once the run ends")
	var over = fresh.get_node("UI/GameOver")
	_expect(over.visible, "game over panel is shown")
	print("death: alive=%s root_active=%s gameover_visible=%s"
		% [fresh.alive, fresh_root.active, over.visible])

	if _fails == 0:
		print("RESULT: PASS")
	else:
		print("RESULT: FAIL (%d checks failed)" % _fails)
	quit(0 if _fails == 0 else 1)
	return true


func _expect(ok: bool, what: String) -> void:
	if ok:
		print("  ok: %s" % what)
	else:
		_fails += 1
		push_error("FAILED: %s" % what)
