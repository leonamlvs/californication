shader_type canvas_item;
render_mode unshaded;

uniform vec4 edge_color : source_color = vec4(0.90, 0.90, 0.97, 1.0);
uniform vec4 halo_color : source_color = vec4(0.68, 0.67, 0.88, 1.0);
uniform float surface_opacity : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float edge_strength : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float halo_strength : hint_range(0.0, 1.0, 0.01) = 0.95;
uniform float edge_width_px : hint_range(0.5, 4.0, 0.1) = 1.0;
uniform float halo_radius_px : hint_range(1.0, 16.0, 0.25) = 14.0;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec4 source = texture(TEXTURE, UV);
	float halo_alpha = 0.0;
	float edge_alpha = 0.0;
	float interior_edge_alpha = 1.0;
	vec2 directions[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
	float radius_fractions[6] = float[6](0.07, 0.14, 0.24, 0.45, 0.70, 1.0);
	float weights[6] = float[6](0.025, 0.030, 0.040, 0.055, 0.090, 0.060);
	for (int direction_index = 0; direction_index < 4; direction_index++) {
		float ray_alpha = 0.0;
		for (int radius_index = 0; radius_index < 6; radius_index++) {
			float radius = max(edge_width_px, halo_radius_px * radius_fractions[radius_index]);
			float sampled_alpha = texture(TEXTURE, clamp(UV + directions[direction_index] * texel * radius, vec2(0.0), vec2(1.0))).a;
			ray_alpha += sampled_alpha * weights[radius_index];
			if (radius_index == 0) {
				edge_alpha = max(edge_alpha, sampled_alpha);
				interior_edge_alpha = min(interior_edge_alpha, sampled_alpha);
			}
		}
		halo_alpha = max(halo_alpha, ray_alpha);
	}
	float surface_alpha = source.a * surface_opacity;
	float contour_alpha = max(max(edge_alpha - source.a, source.a - interior_edge_alpha), 0.0) * edge_strength;
	float soft_alpha = halo_alpha * (1.0 - source.a) * halo_strength;
	float combined_alpha = clamp(surface_alpha + contour_alpha + soft_alpha, 0.0, 1.0);
	vec3 combined_color = source.rgb * surface_alpha + edge_color.rgb * contour_alpha + halo_color.rgb * soft_alpha;
	COLOR = vec4(combined_color / max(combined_alpha, 0.0001), combined_alpha);
}
