// Shared surface code for level geometry.
// - Crisp texels (nearest + mipmaps) with a bump normal derived from the
//   texture's own brightness, so classic art picks up real lighting.
// - Vertex color red carries the sector light level; it lights the surface
//   as a soft fill, the way the original's sector lighting did, while
//   torches, the moon and projectiles add real dynamic light on top.

#ifdef HD
// Replacement art: smooth filtering, optional authored normal/roughness maps.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform bool has_roughness = false;
#else
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
#endif
uniform float bump = 2.5;
uniform float glow = 0.0;
uniform vec2 scroll = vec2(0.0);
uniform float wobble = 0.0;
uniform float sector_fill = 0.85;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = UV + scroll * TIME;
	if (wobble > 0.0) {
		uv += vec2(sin(uv.y * 6.2831 + TIME * 1.3), cos(uv.x * 6.2831 + TIME * 1.1)) * wobble;
	}
	vec4 c = texture(albedo_tex, uv);
#ifdef MASKED
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
	vec2 px = 1.0 / vec2(textureSize(albedo_tex, 0));
	float h = luma(c.rgb);
	float hx = luma(texture(albedo_tex, uv + vec2(px.x, 0.0)).rgb);
	float hy = luma(texture(albedo_tex, uv - vec2(0.0, px.y)).rgb);
	vec3 tn = normalize(vec3((h - hx) * bump, (h - hy) * bump, 1.0));
	float rough = clamp(0.92 - h * 0.5, 0.35, 1.0);
#ifdef HD
	if (has_normal) {
		tn = normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
	}
	if (has_roughness) {
		rough = texture(roughness_tex, uv).r;
	}
#endif
	vec3 n = normalize(TANGENT * tn.x + BINORMAL * tn.y + NORMAL * tn.z);
	NORMAL = n;

	ALBEDO = c.rgb;
	ROUGHNESS = rough;
	SPECULAR = 0.4;

	// Sector light as a directional-ish fill so bumps still read in areas
	// without dynamic lights.
	float sector = COLOR.r;
	vec3 fill_dir = normalize((VIEW_MATRIX * vec4(0.35, 0.85, 0.25, 0.0)).xyz);
	float shade = 0.72 + 0.28 * dot(n, fill_dir);
	EMISSION = c.rgb * (pow(sector, 1.6) * sector_fill * shade + glow);
}
