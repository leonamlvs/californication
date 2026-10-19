shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Untouched screenshot beneath the 3D island: land, beach and waves stay baked in.
// Only the outer rectangular frame margin joins the surrounding sea.
uniform sampler2D color_plate : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D deep_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform mat4 island_from_world;
uniform vec2 map_size = vec2(32.0, 24.536174);
uniform vec2 map_center = vec2(0.0);
uniform float deep_tile_size = 16.0;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 local_position = (island_from_world * vec4(world_position, 1.0)).xyz;
    vec2 uv = (local_position.xz - map_center) / map_size + vec2(0.5);
    vec2 bounded_uv = clamp(uv, vec2(0.0), vec2(1.0));
    float inside = step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
    vec2 frame_edge = min(uv, vec2(1.0) - uv);
    float coverage = smoothstep(0.0, 0.045, min(frame_edge.x, frame_edge.y)) * inside;
    vec3 coast = texture(color_plate, bounded_uv).rgb;
    vec3 sea = texture(deep_texture, world_position.xz / max(deep_tile_size, 0.001)).rgb;
    ALBEDO = mix(sea, coast, coverage);
}
