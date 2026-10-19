shader_type sky;
// The night outside the windows, painted by compass bearing at infinity, so every window shows
// the same view in its own direction. A profile texture (built by outside.gd from the site's
// "outside" data) gives, for each bearing: the top of the land against the sky, where the water
// begins below the horizon, and how many town and shore lights there are. The moon, its glow and
// the glitter path on the water follow the moon light. Underground it is black.

// x: bearing / 360 + 0.5. r: far land top (deg), g: near shore (deg; >= 0 means no water),
// b: town light density, a: shore light density
uniform sampler2D profile : filter_linear, repeat_enable;
uniform vec3 zenith : source_color;
uniform vec3 horizon : source_color;
uniform vec3 moon_color : source_color;
uniform vec3 glow : source_color;
uniform vec3 land : source_color;
uniform vec3 near_land : source_color;
uniform vec3 water : source_color;
uniform vec3 shallows : source_color;
uniform vec3 glitter : source_color;
uniform vec3 light : source_color;
// degrees across; the real moon is about half a degree
uniform float moon_size = 0.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// a point of light in a grid of cells (deg units), present where hash < density
float lights(vec2 q, float density, float seed) {
	vec2 c = floor(q);
	if (hash(c + seed) >= density) {
		return 0.0;
	}
	vec2 at = vec2(hash(c + seed + 3.1), hash(c + seed + 5.7)) * 0.5 + 0.25;
	float s = smoothstep(0.3, 0.05, length((fract(q) - at) * vec2(1.0, 0.8)));
	return s * (0.5 + hash(c + seed + 9.3));
}

void sky() {
	if (POSITION.y < -1.0) {
		COLOR = vec3(0.0);
	} else {
		vec3 d = normalize(EYEDIR);
		float e = degrees(asin(clamp(d.y, -1.0, 1.0)));
		float b = degrees(atan(d.x, -d.z));
		vec4 p = texture(profile, vec2(b / 360.0 + 0.5, 0.5));
		vec3 md = normalize(LIGHT0_DIRECTION);
		float mb = degrees(atan(md.x, -md.z));
		float moon_up = smoothstep(0.0, 5.0, degrees(asin(md.y)));
		float ang = degrees(acos(clamp(dot(d, md), -1.0, 1.0)));

		// sky: moonlit haze low down, darkening overhead, the moon and its glow, faint stars
		vec3 col = mix(horizon, zenith, pow(clamp(e / 40.0, 0.0, 1.0), 0.55));
		col += glow * (0.45 * exp(-ang / 5.0) + 0.15 * exp(-ang / 28.0)) * moon_up;
		if (!AT_CUBEMAP_PASS && e > 2.0) {
			vec2 q = vec2(b, e) * 5.0;
			float h = hash(floor(q));
			float star = smoothstep(0.25, 0.0, length(fract(q) - 0.5)) * step(0.986, h) * (h - 0.986) * 60.0;
			col += vec3(star) * smoothstep(2.0, 10.0, e) * smoothstep(6.0, 30.0, ang);
		}
		col = mix(col, moon_color, smoothstep(moon_size * 0.5, moon_size * 0.5 - 0.06, ang) * moon_up);

		// land against the sky: a ragged line of treetops
		float top = p.r;
		if (top > 0.03) {
			top += (hash(vec2(floor(b * 6.0), 1.0)) - 0.5) * 0.12 * min(1.0, top * 4.0);
		}
		float shore = p.g;
		if (e < top) {
			bool wet = shore < 0.0 && e < 0.0 && e > shore;
			if (wet) {
				// water: pale shallows at the near shore, deep further out, the moon's glitter
				// path widening toward the viewer, haze at the horizon
				float depth = clamp((e - shore) / max(-shore, 0.01), 0.0, 1.0);
				col = mix(shallows, water, smoothstep(0.0, 0.3, depth));
				float db = abs(mod(b - mb + 180.0, 360.0) - 180.0);
				float width = 0.4 + 1.6 * (-e);
				float path = exp(-pow(db / width, 2.0));
				if (!AT_CUBEMAP_PASS) {
					float g = step(0.86, hash(floor(vec2(b * 14.0, e * 45.0))));
					col += glitter * path * (0.08 + 0.7 * g) * smoothstep(0.0, 0.3, -e) * moon_up;
					// far shore lights reflected as short streaks
					float column = lights(vec2(b * 5.0, 0.5), p.a, 31.0);
					col += light * column * 0.35 * smoothstep(-0.7, 0.0, e);
				}
				col = mix(col, horizon, smoothstep(-0.5, 0.0, e) * 0.55);
			} else {
				col = e > 0.0 ? land : near_land;
				if (!AT_CUBEMAP_PASS) {
					// shore lights just above the far waterline, town lights on the land this side of it
					if (e > 0.0 && e < 0.3) {
						col += light * lights(vec2(b * 5.0, 0.5), p.a, 31.0) * smoothstep(0.3, 0.0, abs(e - 0.1) * 6.0) * 0.8;
					}
					float s0 = min(shore, 0.0);
					if (e < s0 - 0.05 && e > s0 - 1.8) {
						col += light * lights(vec2(b * 5.0, e * 8.0), p.b * 0.22, 17.0) * 0.6;
					}
				}
			}
		}
		COLOR = col;
	}
}
