class_name Projectile
extends Node3D
## A fast shot that flies in a straight line (port of Projectile.ts).
##
## Every physics step it sweeps a small sphere against the world and stops at
## the first wall; before that it checks hits against enemies or the player,
## depending on its damage group.

enum DamageGroup { PLAYER, ENEMY }

const C = preload("res://scripts/game_constants.gd")
## Seconds before a projectile disappears on its own.
const LIFETIME := 3.0
## Radius of the projectile sphere and its sweep shape.
const MESH_RADIUS := 0.08
## Hit cylinder of the player, relative to the feet.
const PLAYER_HIT_Y_MIN := 0.0
const PLAYER_HIT_Y_MAX := 1.4

static var _sweep_shape: SphereShape3D

var velocity := Vector3.ZERO
var damage := 0.0
var group := DamageGroup.ENEMY
var _age := 0.0
var _prev := Vector3.ZERO
var _game: Node
var _player: Player


## Creates a projectile. The first sweep starts at the shooter (spawn_pos), so a
## spawn offset lying in or behind a wall counts as a wall hit.
static func create(game: Node, player: Player, spawn_pos: Vector3, spawn_offset: Vector3,
		shoot_dir: Vector3, speed: float, dmg: float, color: Color, damage_group: DamageGroup) -> Projectile:
	var p := Projectile.new()
	p._game = game
	p._player = player
	p.position = spawn_pos + spawn_offset
	p._prev = spawn_pos
	p.velocity = shoot_dir.normalized() * speed
	p.damage = dmg
	p.group = damage_group

	var mesh := SphereMesh.new()
	mesh.radius = MESH_RADIUS
	mesh.height = MESH_RADIUS * 2
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(inst)
	return p


func _physics_process(dt: float) -> void:
	_age += dt
	if _age > LIFETIME:
		queue_free()
		return

	position += velocity * dt

	# Earliest wall contact on prev -> position: the flight path ends there, so
	# targets behind the wall are not hit and targets in front are not skipped.
	var reach := _sweep_walls(_prev, position)
	var o := _prev
	var d := (position - _prev) * reach
	var hit_wall := reach < 1.0
	if hit_wall:
		position = o + d

	if group == DamageGroup.ENEMY:
		for enemy in _game.get_enemies():
			if not enemy.is_alive():
				continue
			var foot: Vector3 = enemy.global_position
			if _segment_hits_cylinder(o, d, foot.x, foot.z, C.ENEMY_RADIUS,
					foot.y + enemy.HIT_Y_MIN, foot.y + enemy.HIT_Y_MAX):
				enemy.take_damage(damage)
				queue_free()
				return
	elif is_instance_valid(_player):
		var foot := _player.global_position
		if _segment_hits_cylinder(o, d, foot.x, foot.z, C.PLAYER_RADIUS,
				foot.y + PLAYER_HIT_Y_MIN, foot.y + PLAYER_HIT_Y_MAX):
			_player.take_damage(damage)
			queue_free()
			return

	if hit_wall:
		queue_free()
		return
	_prev = position


## Fraction (0..1) of the motion from -> to that is free of world geometry.
func _sweep_walls(from: Vector3, to: Vector3) -> float:
	if _sweep_shape == null:
		_sweep_shape = SphereShape3D.new()
		_sweep_shape.radius = MESH_RADIUS
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _sweep_shape
	params.transform = Transform3D(Basis(), from)
	params.motion = to - from
	params.collision_mask = C.LAYER_WORLD
	var result := get_world_3d().direct_space_state.cast_motion(params)
	return result[0] if result.size() > 0 else 1.0


## Whether the segment o + t*d (t in 0..1) hits a vertical cylinder.
## Projects the cylinder center onto the segment in the XZ plane, then checks
## the radius and the height at that closest point.
static func _segment_hits_cylinder(o: Vector3, d: Vector3, cx: float, cz: float,
		radius: float, y_min: float, y_max: float) -> bool:
	var len_sq := d.x * d.x + d.z * d.z
	var t := 0.0
	if len_sq > 1e-12:
		t = clampf(((cx - o.x) * d.x + (cz - o.z) * d.z) / len_sq, 0.0, 1.0)
	var near_x := o.x + t * d.x - cx
	var near_z := o.z + t * d.z - cz
	if near_x * near_x + near_z * near_z >= radius * radius:
		return false
	var near_y := o.y + t * d.y
	return near_y >= y_min and near_y <= y_max
