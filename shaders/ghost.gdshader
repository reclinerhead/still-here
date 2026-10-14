// Echoes of the residents. Blocky world-space noise dissolves them in as `reveal` rises,
// a soft rim shows their outline, and the cells drift upward so they shimmer.
// They fade when the camera is very close, so they never read as solid glass.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.66);

varying vec3 world_pos;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = hash(floor(world_pos * 14.0 + vec3(0.0, TIME * 0.6, 0.0)));
	if (n > reveal) {
		discard;
	}
	float edge = smoothstep(reveal - 0.12, reveal, n);
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	float near = smoothstep(0.5, 2.6, length(CAMERA_POSITION_WORLD - world_pos));
	float a = ((0.10 + 0.34 * fres) * clamp(reveal * 1.4, 0.0, 1.0) + edge * 0.3) * mix(0.18, 1.0, near);
	ALBEDO = tint * (0.85 + edge * 1.2);
	ALPHA = a;
}
