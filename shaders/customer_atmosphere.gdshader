shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 0.78;
uniform float warmth : hint_range(0.0, 1.0) = 0.32;
uniform float brightness : hint_range(0.5, 1.2) = 0.88;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luminance), source.rgb, saturation);
	vec3 amber = graded * vec3(1.06, 0.88, 0.70);
	graded = mix(graded, amber, warmth);
	float window_light = 1.0 - smoothstep(0.0, 1.0, UV.x);
	graded *= brightness + window_light * 0.07;
	COLOR = vec4(graded, source.a);
}
