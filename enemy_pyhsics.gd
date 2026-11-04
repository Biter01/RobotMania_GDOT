class_name Enemy
extends CharacterBody3D
## A robot enemy rendered as an animated, direction-dependent Sprite3D (port of Enemy.ts).
##
## The node's origin is at the feet. Movement and decisions come from its
## EnemyAI; the sprite frame comes from the animation state and the angle to the viewer.

enum Activity { IDLE, WALK, SHOOT, DEAD }

const C = preload("res://scripts/game_constants.gd")
const COLOR_ALIVE := Color.WHITE
const COLOR_DEAD := Color8(0x55, 0x55, 0x55)
const COLOR_FLASH := Color8(0xff, 0x88, 0x88)
const FLASH_DURATION := 0.12
## Hit cylinder of the enemy, relative to the feet.
const HIT_Y_MIN := 0.0
const HIT_Y_MAX := 1.4
const ATTACK_COOLDOWN := 0.3
const PROJECTILE_DAMAGE := 10.0
const PROJECTILE_SPEED := 70.0
const PROJECTILE_COLOR := Color8(0xdb, 0x46, 0x46)

## Animations of the sprite sheet RoboOrginalNew.png (102 frames x 128 px):
## name -> [first frame, frame count, fps].
const ANIMS := {
	"IdleFront": [0, 6, 4], "Idle34FrontRight": [6, 6, 4], "Idle34FrontLeft": [12, 6, 4],
	"IdleRight": [18, 6, 4], "IdleLeft": [24, 6, 4], "Idle34BackLeft": [30, 6, 4],
	"Idle34BackRight": [36, 6, 4], "IdleBack": [42, 6, 4],
	"WalkFront": [48, 6, 10], "Walk34FrontRight": [54, 6, 10], "Walk34FrontLeft": [60, 6, 10],
	"WalkRight": [66, 6, 5], "WalkLeft": [72, 6, 5], "Walk34BackLeft": [78, 6, 10],
	"Walk34BackRight": [84, 6, 10], "WalkBack": [90, 6, 10],
	"ShootingFront": [96, 2, 6], "Shooting34FrontRight": [98, 2, 6], "Shooting34FrontLeft": [100, 2, 6],
}
## View sector (0 = viewer in front, counter-clockwise in 45 deg steps) -> animation.
## Sectors 3 and 5 are swapped, as in the original, so the sheet looks correct.
const IDLE_BY_SECTOR := ["IdleFront", "Idle34FrontLeft", "IdleLeft", "Idle34BackRight",
	"IdleBack", "Idle34BackLeft", "IdleRight", "Idle34FrontRight"]
const WALK_BY_SECTOR := ["WalkFront", "Walk34FrontLeft", "WalkLeft", "Walk34BackRight",
	"WalkBack", "Walk34BackLeft", "WalkRight", "Walk34FrontRight"]

## Direction the enemy looks in; picks the sprite view.
var facing := Vector3(0, 0, -1)

var _hp := C.ENEMY_HP
var _alive := true
var _flash_timer := 0.0
var _activity := Activity.IDLE
var _ai: EnemyAI
var _cooldown_timer := ATTACK_COOLDOWN
var _anim := ""
var _anim_frame := 0
var _anim_elapsed := 0.0
var _game: Node
var _probe_shape: CylinderShape3D

@onready var sprite: Sprite3D = $Sprite3D
## Follows paths over the NavigationRegion3D of the level (baked navmesh).
@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	_ai = EnemyAI.new(self)
	_game = get_tree().get_first_node_in_group("game")
	_play("IdleFront")


func _physics_process(dt: float) -> void:
	var player: Player = _game.player if _game else null
	if player == null or not _game.is_playing():
		return

	if _alive:
		var move := _ai.update(dt, player.get_eye())
		velocity.x = move.x
		velocity.z = move.z
		if not is_on_floor():
			velocity.y = maxf(velocity.y - C.GRAVITY * dt, -C.MAX_FALL_SPEED)
		move_and_slide()
		_update_direction(player.get_eye())
		if _activity == Activity.SHOOT:
			_attack_player(player, dt)

	_update_animation(dt)

	if _flash_timer > 0:
		_flash_timer -= dt
		if _flash_timer <= 0:
			sprite.modulate = COLOR_ALIVE if _alive else COLOR_DEAD
			if not _alive:
				# Dead enemies are removed once their hit flash is over
				queue_free()


## Position of the sprite center (feet + ENEMY_BASE_HEIGHT); used for distances and shots.
func get_center() -> Vector3:
	return global_position + Vector3(0, C.ENEMY_BASE_HEIGHT, 0)


## Sets what the enemy is doing; drives the animation state.
func set_activity(activity: Activity) -> void:
	if _alive:
		_activity = activity


func is_alive() -> bool:
	return _alive


## Applies damage and starts the hit flash; at 0 HP the enemy dies.
func take_damage(amount: float) -> void:
	_hp -= amount
	if _hp <= 0:
		_alive = false
		_activity = Activity.DEAD
		collision_layer = 0
	sprite.modulate = COLOR_FLASH
	_flash_timer = FLASH_DURATION


## Whether a horizontal move by `motion` stays clear of walls.
func can_move(motion: Vector3) -> bool:
	if _probe_shape == null:
		_probe_shape = CylinderShape3D.new()
		_probe_shape.radius = C.ENEMY_RADIUS
		_probe_shape.height = C.ENEMY_BASE_HEIGHT - 0.1
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _probe_shape
	# Lifted a bit so resting on the floor does not count as a collision
	params.transform = Transform3D(Basis(), global_position + motion + Vector3(0, 0.05 + _probe_shape.height / 2.0, 0))
	params.collision_mask = C.LAYER_WORLD
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _attack_player(player: Player, dt: float) -> void:
	_cooldown_timer -= dt
	if _cooldown_timer > 0:
		return
	var to_player := (player.get_eye() - get_center()).normalized()
	_game.spawn_projectile(Projectile.create(_game, player, get_center(),
		Vector3(to_player.x, 0, to_player.z), to_player, PROJECTILE_SPEED,
		PROJECTILE_DAMAGE, PROJECTILE_COLOR, Projectile.DamageGroup.PLAYER))
	_cooldown_timer = ATTACK_COOLDOWN


func _view_sector(viewer_pos: Vector3) -> int:
	var to_viewer = viewer_pos - get_center()
	to_viewer.y = 0
	to_viewer = to_viewer.normalized()

	var facing_angle = atan2(facing.z, facing.x)
	var viewer_angle = atan2(to_viewer.z, to_viewer.x)

	var angle = fposmod(facing_angle - viewer_angle, TAU)

	var sector = roundi(angle / (PI * 0.25))

	return sector % 8


func _update_direction(viewer_pos: Vector3) -> void:
	var sector := _view_sector(viewer_pos)
	match _activity:
		Activity.IDLE: _play(IDLE_BY_SECTOR[sector])
		Activity.WALK: _play(WALK_BY_SECTOR[sector])
		Activity.SHOOT: _play("ShootingFront")


## Switches to an animation unless it is already playing.
func _play(anim: String) -> void:
	if anim == _anim:
		return
	_anim = anim
	_anim_frame = 0
	_anim_elapsed = 0.0
	sprite.frame = ANIMS[anim][0]


func _update_animation(dt: float) -> void:
	# Dead enemies hold their last frame
	if not _alive or _anim == "":
		return
	var cfg: Array = ANIMS[_anim]
	_anim_elapsed += dt
	var frame_duration: float = 1.0 / cfg[2]
	if _anim_elapsed >= frame_duration:
		_anim_elapsed -= frame_duration
		_anim_frame = (_anim_frame + 1) % cfg[1]
		sprite.frame = cfg[0] + _anim_frame
