shader_type spatial;
// Layered decay for walls, floors and ceilings. Layer A (paint, tiles) is projected in world
// space and breaks away to layer B (bare plaster and brick, concrete) where a large-scale mask
// says so: more near the floor, with grime along the broken edges and water streaks running
// down. World-space projection means no UVs are needed and nothing repeats along a corridor.

render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D a_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float a_metres = 1.0;
uniform vec3 a_tint : source_color = vec3(1.0);
// below 1 lifts the darks of layer A, softening a texture that reads too contrasty in dim light
uniform float a_gamma = 1.0;
// saturated red paint in layer A is repainted this colour (for the green wainscot)
uniform vec3 a_recolor : source_color = vec3(1.0);
uniform float a_recolor_amount = 0.0;
// re-tints all of layer A to one hue, keeping only its (softened) light and dark: for wood
uniform vec3 a_colorize : source_color = vec3(1.0);
uniform float a_colorize_amount = 0.0;

uniform sampler2D b_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float b_metres = 1.0;
uniform vec3 b_tint : source_color = vec3(1.0);

uniform sampler2D mask : filter_linear_mipmap, repeat_enable;
uniform float mask_metres = 6.0;
// share of the surface broken back to layer B, and how much more of it near the floor
uniform float damage = 0.25;
uniform float floor_damage = 0.2;
uniform float grime = 0.5;
uniform float streaks = 0.4;
uniform float roughness_scale = 1.0;
// the presence tint: cold and grey, warming as the ward is restored
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// A macro rather than a function: Godot won't pass samplers with different hints (colour,
// normal, data) through one function. Image rows run downward, so world up is -v on walls.
#define tri(t, p, w) (texture(t, vec2((p).z, -(p).y)) * (w).x + texture(t, (p).xz) * (w).y + texture(t, vec2((p).x, -(p).y)) * (w).z)

void fragment() {
	vec3 w = pow(abs(wnrm), vec3(6.0));
	w /= (w.x + w.y + w.z);
	vec3 pa = wpos / a_metres;
	vec3 pb = wpos / b_metres;
	float n = tri(mask, wpos / mask_metres, w).r;
	float fine = tri(mask, wpos / (mask_metres * 0.13), w).r;
	float near_floor = 1.0 - smoothstep(0.05, 1.1, wpos.y);
	float m = n * 0.8 + fine * 0.2 + floor_damage * near_floor * (1.0 - w.y);
	float cut = 1.0 - damage;
	float b = smoothstep(cut - 0.015, cut + 0.015, m);
	// a dark tide line of grime just outside the broken edge
	float edge = smoothstep(cut - 0.09, cut - 0.01, m) * (1.0 - b);

	vec4 ca = tri(a_albedo, pa, w);
	float chroma = ca.r - max(ca.g, ca.b);
	float paint = smoothstep(0.03, 0.12, chroma) * a_recolor_amount;
	float lum = dot(ca.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col_a = mix(ca.rgb, a_recolor * lum * 2.4, paint);
	col_a = mix(col_a, a_colorize * mix(0.22, lum, 0.55) * 2.4, a_colorize_amount);
	col_a = pow(col_a, vec3(a_gamma)) * a_tint;
	vec3 col_b = tri(b_albedo, pb, w).rgb * b_tint;
	vec3 col = mix(col_a, col_b, b);

	// water streaks run down vertical faces from above; dirt gathers at the bottom
	float vertical = 1.0 - w.y;
	float sx = dot(wpos.xz, vec2(1.0 - w.x, 1.0 - w.z));
	float streak = texture(mask, vec2(sx * 0.9, wpos.y * 0.035)).r;
	streak = smoothstep(0.55, 0.85, streak) * vertical * streaks;
	float dirt = near_floor * vertical * 0.35 + (1.0 - vertical) * fine * 0.25;
	col *= 1.0 - clamp(edge * 0.45 * grime + streak * 0.35 + dirt * grime, 0.0, 0.8);

	vec3 arm_a = tri(a_arm, pa, w).rgb;
	vec3 arm_b = tri(b_arm, pb, w).rgb;
	vec3 arm = mix(arm_a, arm_b, b);
	ALBEDO = col * tint;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = clamp(arm.g * roughness_scale + edge * 0.1, 0.05, 1.0);
	METALLIC = 0.0;
	NORMAL_MAP = mix(tri(a_normal, pa, w).rgb, tri(b_normal, pb, w).rgb, b);
}
