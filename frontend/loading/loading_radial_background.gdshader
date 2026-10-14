shader_type canvas_item;

uniform vec4 center_color : source_color = vec4(0.278431, 0.278431, 0.615686, 1.0);
uniform vec4 border_color : source_color = vec4(0.184314, 0.203922, 0.513725, 1.0);

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radius = clamp(length(centered_uv) / 0.85, 0.0, 1.0);
	COLOR = mix(center_color, border_color, smoothstep(0.0, 1.0, radius));
}
