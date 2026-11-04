extends Node3D
## Owns the player, the projectiles and the UI, and runs the game states
## (port of Game.ts, main.ts and UIRenderer.ts). The level itself (DEMO_3D) is
## built in the editor under the Level node; enemies live under Enemies.

enum State { MENU, PLAYING, GAMEOVER }

const C = preload("res://scripts/game_constants.gd")
const UI_FONT_NAMES: PackedStringArray = ["Courier New", "monospace"]
const COLOR_TITLE := Color8(0xee, 0x00, 0x00)
const COLOR_TITLE_SHADOW := Color8(0x88, 0x00, 0x00)

## Set by Retry: the reloaded scene skips the menu and starts right away.
static var _skip_menu := false

var state := State.MENU
var invincible := false

var _projectiles: Node3D
var _fx_material: ShaderMaterial
var _menu: Control
var _gameover: Control
var _hud: Control
var _fps_label: Label
var _health_label: Label
var _blink_time := 0.0
var _blink_labels: Array[Label] = []
var _font: SystemFont

@onready var player: Player = $Player
@onready var _enemies: Node3D = $Enemies


func _ready() -> void:
	_projectiles = Node3D.new()
	_projectiles.name = "Projectiles"
	add_child(_projectiles)

	_build_ui()
	if _skip_menu:
		_skip_menu = false
		_set_state(State.PLAYING)
	else:
		_set_state(State.MENU)


func is_playing() -> bool:
	return state == State.PLAYING


## Living (not yet removed) enemies of the level.
func get_enemies() -> Array[Node]:
	return _enemies.get_children()


## Adds a new projectile to the running game.
func spawn_projectile(p: Projectile) -> void:
	_projectiles.add_child(p)


func _set_state(next: State) -> void:
	state = next
	_menu.visible = next == State.MENU
	_gameover.visible = next == State.GAMEOVER
	_hud.visible = next == State.PLAYING
	if next == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Release the mouse so the cursor is available for the retry button
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match state:
			State.MENU:
				_set_state(State.PLAYING)
			State.PLAYING:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle_invincible()


func _process(dt: float) -> void:
	_blink_time += dt
	for label in _blink_labels:
		# CSS "blink 1s step-end": visible for half a second, hidden for half a second
		label.modulate.a = 1.0 if fmod(_blink_time, 1.0) < 0.5 else 0.0

	_fx_material.set_shader_parameter("damage_intensity", player.damage_flash_intensity)
	if state != State.PLAYING:
		return
	if not player.is_alive():
		_set_state(State.GAMEOVER)
		return
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_health_label.text = "INVINCIBLE" if invincible else "Health: %d" % maxf(player.health, 0)


## Toggles player invincibility (Tab).
func _toggle_invincible() -> void:
	invincible = not invincible
	player.invincible = invincible


func _retry() -> void:
	_skip_menu = true
	get_tree().reload_current_scene()


func _build_ui() -> void:
	_font = SystemFont.new()
	_font.font_names = UI_FONT_NAMES
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE

	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 0
	add_child(fx_layer)
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_material = ShaderMaterial.new()
	_fx_material.shader = preload("res://shaders/screen_fx.gdshader")
	fx.material = _fx_material
	fx_layer.add_child(fx)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_hud)
	_fps_label = _hud_label(Vector2(12, 12))
	_health_label = _hud_label(Vector2(12, 30))

	_menu = _overlay("ROBOT MANIA")
	_menu.get_child(0).add_child(_blinking_label("[ CLICK TO START ]"))
	ui_layer.add_child(_menu)

	_gameover = _overlay("GAME OVER")
	var retry := Button.new()
	retry.flat = true
	retry.text = "↻"
	retry.add_theme_font_override("font", _font)
	retry.add_theme_font_size_override("font_size", 48)
	retry.add_theme_color_override("font_hover_color", COLOR_TITLE)
	retry.focus_mode = Control.FOCUS_NONE
	retry.pressed.connect(_retry)
	_gameover.get_child(0).add_child(retry)
	_gameover.get_child(0).add_child(_blinking_label("[ RETRY ]"))
	ui_layer.add_child(_gameover)


func _hud_label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_hud.add_child(label)
	return label


## Full-screen dark overlay with a red title; extra content goes into child 0 (a VBox).
func _overlay(title: String) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Clicks pass through to _unhandled_input (menu start); only buttons catch them
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 32)
	bg.add_child(box)
	var label := Label.new()
	label.text = " ".join(title.split(""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", COLOR_TITLE)
	label.add_theme_color_override("font_shadow_color", COLOR_TITLE_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(label)
	return bg


func _blinking_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 16)
	_blink_labels.append(label)
	return label
