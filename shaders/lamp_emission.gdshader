shader_type canvas_item;
render_mode unshaded;

uniform vec2 patch_size = vec2(330.0, 165.0);
uniform float emission = 0.0;
varying vec2 patch_uv;

void vertex() {
	patch_uv = VERTEX / patch_size;
}

void fragment() {
	float radius = length((patch_uv - vec2(0.5)) * vec2(2.0, 2.4));
	float soft_edge = 1.0 - smoothstep(0.40, 1.0, radius);
	vec4 painted_lamp = texture(TEXTURE, UV);
	COLOR = vec4(painted_lamp.rgb * vec3(1.0, 0.97, 0.88), painted_lamp.a * soft_edge * emission);
}
