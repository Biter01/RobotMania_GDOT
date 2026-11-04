extends MeshInstance3D
## The player's pistol (port of Pistol.ts / Weapon.ts): the waffe2.png sprite on a
## quad attached to the camera, firing one projectile per click.

const C = preload("res://scripts/game_constants.gd")
## Offset from the camera to the barrel, along the camera's right and down axes.
const BARREL_OFFSET_RIGHT := 0.0
const BARREL_OFFSET_DOWN := 0.3

var _cooldown_timer := C.PISTOL_COOLDOWN
var _clicked := false
var _game: Node


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_clicked = true


func _physics_process(dt: float) -> void:
	if not _game.is_playing():
		_clicked = false
		return
	_cooldown_timer -= dt
	# A click during the cooldown is consumed and lost, as in the original
	var clicked := _clicked
	_clicked = false
	if not clicked or _cooldown_timer > 0:
		return
	_cooldown_timer = C.PISTOL_COOLDOWN

	var camera := get_parent() as Camera3D
	var basis := camera.global_transform.basis
	var forward := -basis.z
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward)
	var offset := right * BARREL_OFFSET_RIGHT - up * BARREL_OFFSET_DOWN

	_game.spawn_projectile(Projectile.create(_game, _game.player, camera.global_position,
		offset, forward, C.PROJECTILE_SPEED, C.PISTOL_DAMAGE, Color.WHITE,
		Projectile.DamageGroup.ENEMY))
