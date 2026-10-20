class_name Damage
## Area damage shared by explosions.


static func splash(at: Vector3, radius: float, amount: float, source: Node3D, skip: Object) -> void:
	var w = Game.world
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	for n in w.get_tree().get_nodes_in_group("damageable"):
		if n == skip or n.dead:
			continue
		var centre: Vector3 = n.global_position + Vector3(0, float(n.height) * 0.5, 0)
		var d := at.distance_to(centre)
		if d > radius:
			continue
		var q := PhysicsRayQueryParameters3D.create(at, centre, Layers.WORLD)
		if not space.intersect_ray(q).is_empty():
			continue
		var dmg := amount * (1.0 - d / radius)
		if n == source:
			dmg *= 0.5
		n.take_damage(dmg, source, centre, (centre - at).normalized() * 6.0 * (1.0 - d / radius))
