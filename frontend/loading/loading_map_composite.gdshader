shader_type canvas_item;
render_mode unshaded;

uniform sampler2D blurred_mask : filter_linear, repeat_disable;
uniform vec4 map_tint : source_color = vec4(1.0);
uniform float map_opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 halo_color : source_color = vec4(0.68, 0.67, 0.88, 1.0);
uniform float halo_strength : hint_range(0.0, 1.0) = 0.45;
uniform vec2 halo_direction_bias = vec2(0.30, -0.45);
uniform vec4 shadow_color : source_color = vec4(0.08, 0.07, 0.22, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.10;
uniform vec2 shadow_offset_px = vec2(2.0, 3.0);
// Development preview: 0 composite, 1 artwork, 2 halo, 3 shadow.
uniform int diagnostic_mode = 0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 texel = 1.0 / vec2(textureSize(blurred_mask, 0));
	float exterior = 1.0 - source.a;
	float shadow_mask = texture(blurred_mask, clamp(UV - shadow_offset_px * texel, vec2(0.0), vec2(1.0))).r;
	float shadow_alpha = shadow_mask * shadow_opacity * shadow_color.a * exterior;
	vec2 gradient = vec2(
		texture(blurred_mask, UV + vec2(texel.x, 0.0)).g - texture(blurred_mask, UV - vec2(texel.x, 0.0)).g,
		texture(blurred_mask, UV + vec2(0.0, texel.y)).g - texture(blurred_mask, UV - vec2(0.0, texel.y)).g
	);
	// Vary intensity along the silhouette without distorting the Gaussian kernel.
	vec2 outward = -gradient / max(length(gradient), 0.00001);
	float directional_gain = clamp(1.0 + dot(outward, halo_direction_bias), 0.35, 1.6);
	float halo_alpha = texture(blurred_mask, UV).g * 2.0 * halo_strength * halo_color.a * exterior * directional_gain;
	float surface_alpha = source.a * map_opacity * map_tint.a;
	if (diagnostic_mode == 1) { shadow_alpha = 0.0; halo_alpha = 0.0; }
	if (diagnostic_mode == 2) { shadow_alpha = 0.0; surface_alpha = 0.0; }
	if (diagnostic_mode == 3) { halo_alpha = 0.0; surface_alpha = 0.0; }
	vec3 color = shadow_color.rgb * shadow_alpha;
	float alpha = shadow_alpha;
	color = halo_color.rgb * halo_alpha + color * (1.0 - halo_alpha);
	alpha = halo_alpha + alpha * (1.0 - halo_alpha);
	// The transparent source viewport stores premultiplied edge colors.
	vec3 artwork = source.rgb / max(source.a, 0.00001);
	color = artwork * map_tint.rgb * surface_alpha + color * (1.0 - surface_alpha);
	alpha = surface_alpha + alpha * (1.0 - surface_alpha);
	COLOR = vec4(color / max(alpha, 0.00001), alpha);
}
