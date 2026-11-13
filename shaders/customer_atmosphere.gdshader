shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 0.78;
uniform float warmth : hint_range(0.0, 1.0) = 0.32;
uniform float brightness : hint_range(0.5, 1.2) = 0.88;
uniform vec2 mouth_center = vec2(0.5, 0.4);
uniform vec2 left_brow = vec2(0.43, 0.25);
uniform vec2 right_brow = vec2(0.57, 0.25);
uniform float facial_amount = 0.0;
uniform float smile = 0.0;
uniform float doubt = 0.0;
uniform float impatient = 0.0;

float local_weight(vec2 point, vec2 center, vec2 radius) {
	return exp(-dot((point - center) / radius, (point - center) / radius) * 2.0);
}

void fragment() {
	vec2 face_uv = UV;
	float corners = smoothstep(0.008, 0.045, abs(UV.x - mouth_center.x));
	float mouth = local_weight(UV, mouth_center, vec2(0.09, 0.037));
	face_uv.y += mouth * corners * (smile * 0.007 - doubt * 0.003 - impatient * 0.002) * facial_amount;
	float brow_l = local_weight(UV, left_brow, vec2(0.045, 0.021));
	float brow_r = local_weight(UV, right_brow, vec2(0.045, 0.021));
	face_uv.y += (brow_l * (doubt * 0.005 + smile * 0.002 - impatient * 0.002) + brow_r * (smile * 0.002 - doubt * 0.002 - impatient * 0.002)) * facial_amount;
	vec4 source = texture(TEXTURE, face_uv) * COLOR;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luminance), source.rgb, saturation);
	vec3 amber = graded * vec3(1.06, 0.88, 0.70);
	graded = mix(graded, amber, warmth);
	float window_light = 1.0 - smoothstep(0.0, 1.0, UV.x);
	graded *= brightness + window_light * 0.07;
	COLOR = vec4(graded, source.a);
}
