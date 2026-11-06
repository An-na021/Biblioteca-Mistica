shader_type canvas_item;

uniform float motion_time = 0.0;
varying vec4 plant_tint;

void vertex() {
	plant_tint = COLOR;
}

void fragment() {
	// Only foliage moves; the pot and its contact with the counter stay fixed.
	float foliage = 1.0 - smoothstep(0.40, 0.58, UV.y);
	float breeze = sin(motion_time * 0.72) + sin(motion_time * 1.31 + UV.y * 3.0) * 0.30;
	vec2 sample_uv = UV + vec2(breeze * 0.008 * foliage, 0.0);
	COLOR = texture(TEXTURE, sample_uv) * plant_tint;
}
