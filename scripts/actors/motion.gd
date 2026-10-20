class_name Motion
## Character movement with Doom-style step climbing: anything up to `step`
## high is walked onto without jumping.


## Moves the body by its velocity. Returns how far it stepped up (meters).
static func move(body: CharacterBody3D, step: float) -> float:
	var dt := body.get_physics_process_delta_time()
	var h := Vector3(body.velocity.x, 0.0, body.velocity.z) * dt
	if body.is_on_floor() and h.length_squared() > 1e-8 and body.test_move(body.global_transform, h):
		var start := body.global_transform
		var up := step
		var col := KinematicCollision3D.new()
		if body.test_move(start, Vector3(0, step, 0), col):
			up = col.get_travel().y
		if up > 0.01:
			var raised := start.translated(Vector3(0, up, 0))
			if not body.test_move(raised, h):
				var moved := raised.translated(h)
				var down := KinematicCollision3D.new()
				if body.test_move(moved, Vector3(0, -up - 0.02, 0), down) and down.get_normal().y > 0.7:
					var landed := moved.translated(down.get_travel())
					var climbed := landed.origin.y - start.origin.y
					if climbed > 0.01:
						body.global_transform = landed
						# settle onto the floor without moving sideways again
						var keep := body.velocity
						body.velocity = Vector3(0, minf(keep.y, 0.0), 0)
						body.move_and_slide()
						body.velocity = Vector3(keep.x, maxf(keep.y, 0.0), keep.z)
						return climbed
	body.move_and_slide()
	return 0.0
