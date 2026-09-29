extends Node2D

const SOIL_Y := 144.0
const SCREEN_W := 640.0
const SCROLL_Y := 672.0
const START_X := 320.0
const EDGE_PAD := 6.0
const PX_PER_M := 250.0
const GOAL_M := 100.0

const START_HEADING := PI / 2.0 + deg_to_rad(40.0)
const TERRAIN_SEGMENT := 12540.0

const FERT_SCORE := 10
const BOOST_SPEED := 1.8
const BOOST_SECONDS := 4.0
const BOOST_TINT := Color(0.55, 1.0, 0.6)
const HINT := "Move the cursor to steer the root - R to restart"

const MUSIC := preload("res://audio/cozy_game_bg.mp3")
const Course := preload("res://scripts/course.gd")

var alive := true
var deepest := 0.0
var fertilizer_score := 0
var boost_left := 0.0

@onready var world: Node2D = $World
@onready var root: Node2D = $World/Root
@onready var rocks: Node2D = $World/Rocks
@onready var pickups: Node2D = $World/Pickups
@onready var terrain_a: TextureRect = $World/TerrainA
@onready var terrain_b: TextureRect = $World/TerrainB
@onready var hitbox: Area2D = $World/Root/Tip/Hitbox
@onready var depth_label: Label = $UI/DepthLabel
@onready var score_label: Label = $UI/ScoreLabel
@onready var status_label: Label = $UI/StatusLabel
@onready var over: Control = $UI/GameOver
@onready var over_title: Label = $UI/GameOver/Title
@onready var over_message: Label = $UI/GameOver/Message

var _music: AudioStreamPlayer


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	Course.build(rng, rocks, pickups)

	root.start(Vector2(START_X, SOIL_Y + 2.0), START_HEADING)
	root.crossed_own_path.connect(_on_crossed_own_path)
	hitbox.body_entered.connect(_on_hit_body)
	hitbox.area_entered.connect(_on_hit_area)

	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.stream = MUSIC.duplicate() as AudioStreamMP3
	(_music.stream as AudioStreamMP3).loop = true
	_music.play()

	refresh_hud()
	status_label.text = HINT


func _process(delta: float) -> void:
	if not alive:
		return

	tick_boost(delta)
	check_walls()
	if not alive:
		return

	follow_tip()
	wrap_terrain()
	refresh_hud()

	if deepest >= GOAL_M:
		finish("You reached 100 m!", true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func follow_tip() -> void:
	var y: float = root.tip_position.y
	if y + world.position.y > SCROLL_Y:
		world.position.y = SCROLL_Y - y


func wrap_terrain() -> void:
	var y: float = root.tip_position.y

	while y >= terrain_a.offset_top + TERRAIN_SEGMENT:
		terrain_a.offset_top = terrain_b.offset_top + TERRAIN_SEGMENT
		terrain_a.offset_bottom = terrain_a.offset_top + TERRAIN_SEGMENT

	while y >= terrain_b.offset_top + TERRAIN_SEGMENT:
		terrain_b.offset_top = terrain_a.offset_top + TERRAIN_SEGMENT
		terrain_b.offset_bottom = terrain_b.offset_top + TERRAIN_SEGMENT


func refresh_hud() -> void:
	var tip_y: float = root.tip_position.y
	var meters := (tip_y - SOIL_Y) / PX_PER_M
	deepest = maxf(deepest, meters)
	depth_label.text = "Depth %d m" % int(maxf(meters, 0.0))
	score_label.text = "Score %d" % (int(deepest) + fertilizer_score)


func tick_boost(delta: float) -> void:
	if boost_left <= 0.0:
		return

	boost_left -= delta
	if boost_left > 0.0:
		return

	boost_left = 0.0
	root.speed_scale = 1.0
	root.tip.modulate = Color.WHITE
	if alive:
		status_label.text = HINT


func check_walls() -> void:
	var half: float = root.tip.texture.get_width() * 0.5
	var x: float = root.tip_position.x
	var y: float = root.tip_position.y

	if x < EDGE_PAD + half:
		finish("The left wall stopped you.")
	elif x > SCREEN_W - EDGE_PAD - half:
		finish("The right wall stopped you.")
	elif y < SOIL_Y:
		finish("You cannot grow back up into the sky.")


func _on_hit_body(body: Node2D) -> void:
	if not body.is_in_group("rock"):
		return
	body.call("flash")
	finish("The root hit a rock.")


func _on_hit_area(area: Area2D) -> void:
	if not alive or not area.is_in_group("fertilizer"):
		return

	area.call("collect")
	fertilizer_score += FERT_SCORE
	boost_left = BOOST_SECONDS
	root.speed_scale = BOOST_SPEED
	root.tip.modulate = BOOST_TINT
	refresh_hud()
	status_label.text = "Fertilizer! +%d, growing faster" % FERT_SCORE


func _on_crossed_own_path() -> void:
	finish("The root crossed its own path.")


func finish(message: String, won := false) -> void:
	if not alive:
		return

	alive = false
	root.active = false
	boost_left = 0.0
	root.speed_scale = 1.0
	_music.stream_paused = true

	status_label.text = message
	over_title.text = "You Win!" if won else "Game Over"
	over_message.text = message
	over.visible = true
