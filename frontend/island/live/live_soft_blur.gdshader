shader_type canvas_item;
render_mode unshaded;

// Opt-in live-only variant. Mipmap softening removes high-frequency coast
// detail during the blurred pullback; existing cinematic profiles keep their
// original non-mipmapped shader. See Godot's screen-reading shader contract.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 blur_center = vec2(0.5);
uniform float blur_strength = 0.0;
uniform int sample_count = 12;
uniform float effect_mix = 0.0;
uniform float softness_lod = 3.5;

void fragment() {
	float lod = softness_lod * effect_mix;
	vec4 original = textureLod(screen_texture, SCREEN_UV, lod);
	vec4 accumulated = original;
	float weight = 1.0;
	for (int i = 1; i < 12; i++) {
		if (i >= sample_count) { break; }
		float step_amount = float(i) / float(max(sample_count-1,1));
		vec2 uv = clamp(SCREEN_UV + (blur_center-SCREEN_UV)*blur_strength*step_amount,vec2(0.0),vec2(1.0));
		accumulated += textureLod(screen_texture, uv, lod);
		weight += 1.0;
	}
	COLOR = mix(original,accumulated/weight,effect_mix);
}
