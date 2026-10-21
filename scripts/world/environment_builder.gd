class_name EnvironmentBuilder
## Sky, moonlight, fog and post-processing. What gets switched on depends on
## the renderer (Forward+ on desktop, Compatibility on the web) and the
## quality setting.


static func build(world: Node3D, map: MapData, tex: TextureLibrary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_tex: Texture2D = tex.sky_texture(map.sky)
	if sky_tex != null:
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = sky_tex
		pano.energy_multiplier = 1.2
		sky.sky_material = pano
	else:
		var proc := ProceduralSkyMaterial.new()
		proc.sky_top_color = Color(0.05, 0.04, 0.10)
		proc.sky_horizon_color = Color(0.55, 0.22, 0.12)
		proc.ground_horizon_color = Color(0.25, 0.10, 0.07)
		proc.ground_bottom_color = Color(0.02, 0.02, 0.03)
		proc.sky_curve = 0.12
		proc.sun_angle_max = 8.0
		proc.sky_energy_multiplier = 1.4
		sky.sky_material = proc
	env.sky = sky
	# Level surfaces light themselves from their sector's light level (see
	# world.gdshaderinc) and ignore ambient; ambient is the matching fill for
	# characters, items and weapons, which have ordinary PBR materials.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.55, 0.58)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0

	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.16, 0.14)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.15

	var q: int = Game.quality
	if Game.is_forward_plus():
		env.ssao_enabled = q >= Game.Quality.HIGH
		env.ssao_radius = 1.2
		env.ssao_intensity = 2.2
		env.ssil_enabled = q >= Game.Quality.HIGH
		env.ssr_enabled = q >= Game.Quality.ULTRA
		env.ssr_max_steps = 48
		if q >= Game.Quality.ULTRA:
			env.sdfgi_enabled = true
			env.sdfgi_use_occlusion = true
			env.sdfgi_energy = 0.6
			env.sdfgi_cascades = 4
			env.sdfgi_min_cell_size = 0.25
		if q >= Game.Quality.HIGH:
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.012
			env.volumetric_fog_albedo = Color(0.85, 0.8, 0.75)
			env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			env.volumetric_fog_gi_inject = 0.5
			env.volumetric_fog_length = 48.0
			env.fog_enabled = false

	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	# Moonlight. Interiors are shadowed by their ceilings, so it only lights
	# areas open to the sky.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_color = Color(0.75, 0.78, 1.0) if sky_tex == null else Color(1.0, 0.92, 0.8)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 70.0 if q >= Game.Quality.HIGH else 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= Game.Quality.HIGH else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.light_angular_distance = 0.5
	world.add_child(sun)
