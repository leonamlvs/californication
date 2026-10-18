shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D color_plate : source_color, filter_linear_mipmap, repeat_disable;
uniform mat4 island_from_world;
uniform float pixels_per_unit = 30.0;
uniform float elevation_sine = 0.9781476;
uniform vec4 deep_color : source_color = vec4(0.02745, 0.07451, 0.29020, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 local = (island_from_world * vec4(world_position, 1.0)).xyz;
	vec2 uv = vec2((local.x * pixels_per_unit + 480.0) / 960.0,
		(local.z * pixels_per_unit * elevation_sine + 360.0) / 720.0);
	vec2 edge = min(uv, vec2(1.0) - uv);
	float coverage = smoothstep(0.0, 0.045, min(edge.x, edge.y));
	ALBEDO = mix(deep_color.rgb, texture(color_plate, clamp(uv, vec2(0.0), vec2(1.0))).rgb, coverage);
}
