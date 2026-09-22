shader_type canvas_item;
render_mode unshaded;

// Godot 4.7 screen reading uses hint_screen_texture + SCREEN_UV.
// SCREEN_TEXTURE was removed in Godot 4 and must not be used.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 blur_center = vec2(0.5, 0.5);
uniform float blur_strength : hint_range(0.0, 0.25, 0.001) = 0.0;
uniform int sample_count : hint_range(2, 12, 1) = 8;
uniform float effect_mix : hint_range(0.0, 1.0, 0.01) = 0.0;

const int MAX_SAMPLES = 12;

void fragment() {
	vec4 original = texture(screen_texture, SCREEN_UV);
	vec2 toward_center = blur_center - SCREEN_UV;
	vec4 accumulated = original;
	float weight = 1.0;
	for (int sample_index = 1; sample_index < MAX_SAMPLES; sample_index++) {
		if (sample_index >= sample_count) {
			break;
		}
		float step_amount = float(sample_index) / float(max(sample_count - 1, 1));
		vec2 sample_uv = clamp(SCREEN_UV + toward_center * blur_strength * step_amount, vec2(0.0), vec2(1.0));
		accumulated += texture(screen_texture, sample_uv);
		weight += 1.0;
	}
	vec4 blurred = accumulated / weight;
	COLOR = mix(original, blurred, effect_mix);
}
