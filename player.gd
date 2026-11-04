class_name Player
extends CharacterBody3D
## The first-person player: mouse look, WASD movement, health and weapon (port of Player.ts).
## The node's origin is at the feet; the camera sits at PLAYER_EYE_HEIGHT.

const C = preload("res://scripts/game_constants.gd")
const DAMAGE_FLASH_DECAY_RATE := 3.0
const DAMAGE_FLASH_PER_DAMAGE := 0.05
## Upward speed of a jump in units/s (about 0.9 units high at GRAVITY 30).
const JUMP_VELOCITY := 7.5

@export var mouse_sensitivity := C.MOUSE_SENSITIVITY

var health := 100.0
var invincible := false
## 0..1, drives the red vignette of the screen shader.
var damage_flash_intensity := 0.0

var _yaw := PI
var _pitch := 0.0
var _game: Node

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game")
	camera.position = Vector3(0, C.PLAYER_EYE_HEIGHT, 0)
	camera.fov = C.CAMERA_FOV
	camera.near = C.CAMERA_NEAR
	camera.far = C.CAMERA_FAR
	rotation.y = _yaw


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and _game.is_playing():
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity,
			-deg_to_rad(C.PITCH_LIMIT_DEG), deg_to_rad(C.PITCH_LIMIT_DEG))
		rotation.y = _yaw
		camera.rotation.x = _pitch


func _physics_process(dt: float) -> void:
	if not _game.is_playing():
		return

	if not is_on_floor():
		velocity.y = maxf(velocity.y - C.GRAVITY * dt, -C.MAX_FALL_SPEED)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * C.PLAYER_SPEED
	velocity.z = direction.z * C.PLAYER_SPEED
	move_and_slide()

	damage_flash_intensity = clampf(damage_flash_intensity - DAMAGE_FLASH_DECAY_RATE * dt, 0, 1)


## Eye position in world space (feet + PLAYER_EYE_HEIGHT).
func get_eye() -> Vector3:
	return global_position + Vector3(0, C.PLAYER_EYE_HEIGHT, 0)


## Applies damage (unless invincible) and triggers the damage flash.
func take_damage(amount: float) -> void:
	if invincible:
		return
	health -= amount
	damage_flash_intensity = clampf(damage_flash_intensity + amount * DAMAGE_FLASH_PER_DAMAGE, 0, 1)


func is_alive() -> bool:
	return health > 0
