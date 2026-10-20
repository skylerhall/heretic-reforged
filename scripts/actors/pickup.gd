class_name Pickup
extends Area3D
## An item lying in the world. Polls for the player each tick (rather than
## only on enter) so an item you couldn't use yet is taken once you can.

var kind := ""
var _model: Node3D
var _t := 0.0


func setup(k: String) -> void:
	kind = k
	collision_layer = Layers.PICKUP
	collision_mask = Layers.PLAYER
	monitorable = false
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 1.6
	cs.shape = shape
	cs.position.y = 0.8
	add_child(cs)
	_model = Models.pickup(k)
	add_child(_model)
	_t = randf() * TAU


func _physics_process(dt: float) -> void:
	_t += dt
	_model.rotation.y = _t * 1.4
	_model.position.y = 0.35 + sin(_t * 2.2) * 0.08
	for b in get_overlapping_bodies():
		if b is Player and b.give(kind):
			if Game.world != null:
				Game.world.items += 0 if kind.begins_with("key") else 1
			queue_free()
			return
