shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Shadow (R) and halo (G) share normalized Gaussian passes. Each pair combines consecutive
// texels using linear filtering; no sparse radial offsets or directional max.
uniform vec2 axis = vec2(1.0, 0.0);
uniform bool source_is_alpha = true;
uniform vec2 center_weights;
uniform vec2 narrow_pairs[16];
uniform vec2 broad_pairs[16];
uniform int narrow_count;
uniform int broad_count;

void fragment() {
	vec2 texel_axis = axis / vec2(textureSize(TEXTURE, 0));
	vec4 center = texture(TEXTURE, UV);
	vec2 result = (source_is_alpha ? vec2(center.a) : center.rg) * center_weights;
	for (int i = 0; i < 16; i++) {
		if (i < narrow_count) {
			vec2 offset = texel_axis * narrow_pairs[i].x;
			vec4 left = texture(TEXTURE, clamp(UV - offset, vec2(0.0), vec2(1.0)));
			vec4 right = texture(TEXTURE, clamp(UV + offset, vec2(0.0), vec2(1.0)));
			result.r += (source_is_alpha ? left.a + right.a : left.r + right.r) * narrow_pairs[i].y;
		}
		if (i < broad_count) {
			vec2 offset = texel_axis * broad_pairs[i].x;
			vec4 left = texture(TEXTURE, clamp(UV - offset, vec2(0.0), vec2(1.0)));
			vec4 right = texture(TEXTURE, clamp(UV + offset, vec2(0.0), vec2(1.0)));
			result.g += (source_is_alpha ? left.a + right.a : left.g + right.g) * broad_pairs[i].y;
		}
	}
	COLOR = vec4(result, 0.0, 1.0);
}
