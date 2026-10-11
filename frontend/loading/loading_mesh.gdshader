shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 mesh_tint : source_color = vec4(0.72, 0.74, 0.94, 1.0);

void fragment() {
	float face_amount = smoothstep(0.35, 0.92, abs(NORMAL.z));
	float shade = mix(0.52, 1.0, face_amount);
	ALBEDO = mesh_tint.rgb * shade;
}
