shader_type canvas_item;

uniform vec4 white_hot_color : source_color = vec4(1.0, 0.769, 0.0, 0.96);  // Peak Plasma Spots
uniform vec4 core_color : source_color = vec4(1.0, 0.82, 0.15, 1.0);     // Hot Yellow Core
uniform vec4 body_color : source_color = vec4(1.0, 0.35, 0.0, 1.0);      // Fiery Orange
uniform vec4 deep_body_color : source_color = vec4(0.45, 0.04, 0.0, 1.0); // Deep Crimson
uniform vec4 crust_color : source_color = vec4(0.1, 0.02, 0.02, 1.0);    // Obsidian Rim

uniform float outer_edge : hint_range(0.0, 1.0) = 0.35;
uniform float core_start : hint_range(0.0, 1.0) = 0.75;

group_uniforms Motion_And_Swirl;
uniform float flow_speed : hint_range(0.1, 3.0) = 1.0;
uniform float noise_scale : hint_range(1.0, 30.0) = 14.0;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.012;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		val += amp * noise(p);
		p *= 2.02;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 flow_uv = SCREEN_UV * noise_scale;
	vec2 move = vec2(TIME * 0.15 * flow_speed, TIME * 0.35 * flow_speed);
	
	float n1 = fbm(flow_uv + move);
	float n2 = fbm(flow_uv * 1.5 - move * 0.8 + vec2(n1));

	// Distortion for outer edge
	vec2 distorted_uv = SCREEN_UV + (vec2(n1, n2) - 0.5) * distortion_strength;

	// GRIDLINE FIX: textureLod with explicit level 0.0 prevents derivative sampler seams
	float raw_alpha = textureLod(screen_texture, distorted_uv, 0.0).a;

	float edge_alpha = smoothstep(outer_edge - 0.015, outer_edge + 0.015, raw_alpha);
	if (edge_alpha <= 0.0) {
		COLOR = vec4(0.0);
		discard;
	}

	float heat = smoothstep(outer_edge, core_start, raw_alpha);

	// 1. Interior body churn (Crimson -> Orange)
	float churn = sin((n1 + n2 * 0.7) * 14.0 + TIME * flow_speed * 1.2) * 0.5 + 0.5;
	float body_mix = smoothstep(0.1, 0.7, heat * 0.4 + churn * 0.6);
	vec3 lava = mix(deep_body_color.rgb, body_color.rgb, body_mix);

	// 2. Floating rock crust patches inside liquid
	float rock_patches = smoothstep(0.58, 0.78, n1) * (1.0 - heat * 0.75);
	lava = mix(lava, crust_color.rgb, rock_patches);

	// 3. Core turbulence breaking up flat saturation
	float core_turbulence = fbm(flow_uv * 2.5 + vec2(TIME * 0.4 * flow_speed));
	float dynamic_core = clamp(heat * 0.65 + (core_turbulence - 0.45) * 0.7 * heat, 0.0, 1.0);

	// Multi-stage core: Orange -> Hot Yellow -> White-Hot Plasma
	vec3 active_core = mix(body_color.rgb, core_color.rgb, smoothstep(0.2, 0.65, dynamic_core));
	active_core = mix(active_core, white_hot_color.rgb, smoothstep(0.7, 0.95, dynamic_core));

	lava = mix(lava, active_core, smoothstep(0.25, 0.85, heat));

	// 4. Moving plasma filaments
	float plasma_lines = pow(abs(sin(n1 * 10.0 + n2 * 6.0)), 5.0) * heat;
	lava = mix(lava, white_hot_color.rgb, plasma_lines * 0.8);

	// 5. Dark rim
	float rim = smoothstep(outer_edge, outer_edge + 0.08, raw_alpha);
	lava = mix(crust_color.rgb, lava, rim);

	COLOR = vec4(lava, edge_alpha);
}