shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Data textures are linear values, never tagged source_color. Exactly three
// texture samples: one shore lookup and two reads of the same periodic noise.
uniform sampler2D shore_data : filter_linear, repeat_disable;
uniform sampler2D ripple_texture : filter_linear, repeat_enable;
uniform mat4 island_from_world;
uniform vec2 map_size = vec2(32.0, 24.536174);
uniform vec2 map_center = vec2(0.0);
uniform float distance_range = 4.0;
uniform vec4 deep_color : source_color;
uniform vec4 shelf_color : source_color;
uniform vec4 shallow_color : source_color;
uniform vec4 foam_color : source_color;
uniform float wave_spacing = 0.6;
uniform float wave_strength = 0.075;
uniform float wave_reach = 2.2;
uniform float wave_breakup = 0.3;
uniform float ripple_tile_size = 9.0;
uniform float ripple_strength = 0.1;
uniform float wave_phase;
uniform vec2 ripple_offset_a;
uniform vec2 ripple_offset_b;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 local_position = (island_from_world * vec4(world_position, 1.0)).xyz;
	vec2 uv = (local_position.xz - map_center) / map_size + vec2(0.5);
	vec4 shore = texture(shore_data, clamp(uv, vec2(0.0), vec2(1.0)));
	vec2 edge = min(uv, vec2(1.0) - uv);
	float coverage = smoothstep(0.0, 0.02, min(edge.x, edge.y));
	float cyan = shore.g * coverage;
	float shelf = shore.a * coverage;
	// Independent world coordinates: rotating the island cannot rotate the sea.
	vec2 world_uv = world_position.xz / max(ripple_tile_size, 0.001);
	float ripple_a = texture(ripple_texture, world_uv + ripple_offset_a).r;
	vec2 second_uv = vec2(world_uv.x * 0.8 - world_uv.y * 0.6,
		world_uv.x * 0.6 + world_uv.y * 0.8) * 0.73;
	float ripple_b = texture(ripple_texture, second_uv + ripple_offset_b).r;
	float ripple = (ripple_a * 0.65 + ripple_b * 0.35 - 0.5) * 2.0;
	vec3 deep = deep_color.rgb * (1.0 + ripple * ripple_strength);
	vec3 color = deep * max(0.0, 1.0-cyan-shelf) + shallow_color.rgb*cyan + shelf_color.rgb*shelf;
	float distance_from_shore = shore.r * distance_range;
	float band = pow(0.5 + 0.5*cos(6.28318530718 *
		(distance_from_shore / max(wave_spacing, 0.001) - wave_phase + (shore.b-0.5)*wave_breakup)), 10.0);
	float fade = (1.0-smoothstep(wave_reach*0.55, wave_reach, distance_from_shore)) * coverage;
	float foam = band * fade * (0.35 + shore.b*0.65) * wave_strength;
	ALBEDO = mix(color, foam_color.rgb, foam);
}
