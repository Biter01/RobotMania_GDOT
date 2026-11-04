class_name EnemyAI
extends RefCounted
## Decision making and movement of one enemy (port of EnemyAI.ts).
##
## Within ATTACK_RANGE the enemy shoots and occasionally strafes; within
## SIGHT_RANGE it follows a path over the baked navmesh (NavigationAgent3D);
## otherwise it idles.

const C = preload("res://scripts/game_constants.gd")
## Distance up to which the enemy chases the player.
const SIGHT_RANGE := 50.0
## Distance up to which the enemy shoots instead of walking.
const ATTACK_RANGE := 8.0
## Walking speed in units/s.
const SPEED := 3.0
## Seconds between two path recalculations.
const REPLAN_INTERVAL := 0.3
## Seconds one sideways strafe lasts.
const WANDER_TIME := 0.6

var enemy: Enemy
var _replan_timer := randf() * REPLAN_INTERVAL
var _wander_timer := WANDER_TIME
var _is_wandering := false
var _wander_right := false


func _init(owner_enemy: Enemy) -> void:
	enemy = owner_enemy


## Chooses attack, follow or idle behaviour for this step and returns the
## horizontal velocity the enemy should move with.
func update(dt: float, player_pos: Vector3) -> Vector3:
	var dist := enemy.get_center().distance_to(player_pos)
	if dist < ATTACK_RANGE or _is_wandering:
		return _attack_behaviour(player_pos, dt)
	if dist < SIGHT_RANGE:
		enemy.set_activity(Enemy.Activity.WALK)
		return _step_towards_player(dt, player_pos)
	enemy.set_activity(Enemy.Activity.IDLE)
	return Vector3.ZERO


func _attack_behaviour(player_pos: Vector3, dt: float) -> Vector3:
	var velocity := Vector3.ZERO
	if randf() > 0.98 or _is_wandering:
		velocity = _wander_side(player_pos, dt)

	if _is_wandering:
		enemy.set_activity(Enemy.Activity.WALK)
	else:
		enemy.facing = (player_pos - enemy.get_center()).normalized()
		enemy.set_activity(Enemy.Activity.SHOOT)
	return velocity


func _step_towards_player(dt: float, player_pos: Vector3) -> Vector3:
	var agent := enemy.agent
	_replan_timer -= dt
	if _replan_timer <= 0:
		# Target the player's feet, so the navmesh picks the right level
		agent.target_position = player_pos - Vector3(0, C.PLAYER_EYE_HEIGHT, 0)
		_replan_timer = REPLAN_INTERVAL
	if agent.is_navigation_finished():
		return Vector3.ZERO
	return _move_towards(agent.get_next_path_position(), dt)


## Strafes left or right of the player for a short time, if the way is free.
func _wander_side(player_pos: Vector3, dt: float) -> Vector3:
	if _wander_timer == WANDER_TIME:
		_wander_right = randf() > 0.5

	if _wander_timer > 0:
		_wander_timer -= dt
		_is_wandering = true
	else:
		_is_wandering = false
		_wander_timer = WANDER_TIME
		enemy.facing = (player_pos - enemy.get_center()).normalized()

	var to_target := player_pos - enemy.get_center()
	to_target.y = 0 # height differences (stairs) must not tilt the sideways direction
	to_target = to_target.normalized()
	var right := to_target.cross(Vector3.UP).normalized()

	var can_right := enemy.can_move(right * SPEED * dt)
	var can_left := enemy.can_move(-right * SPEED * dt)
	if not can_left or not can_right:
		_is_wandering = false
		_wander_timer = 0

	if _wander_right and can_right:
		enemy.facing = right
		return right * SPEED
	elif can_left:
		enemy.facing = -right
		return -right * SPEED
	return Vector3.ZERO


## Only decides where to go - collisions, stairs and gravity are handled by move_and_slide.
func _move_towards(target: Vector3, dt: float) -> Vector3:
	var to_target := Vector3(target.x, 0, target.z) - Vector3(enemy.global_position.x, 0, enemy.global_position.z)
	var dist := to_target.length()
	if dist <= 0 or dt <= 0:
		return Vector3.ZERO
	enemy.facing = to_target / dist
	# On the last step land exactly on the path point instead of overshooting
	return to_target / dist * minf(SPEED, dist / dt)
