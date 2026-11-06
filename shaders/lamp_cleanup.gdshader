shader_type canvas_item;

uniform vec2 source_size = vec2(1672.0, 941.0);

void fragment() {
	vec2 point = UV * source_size;
	// One continuous mask across the room/counter depth split.
	float horizontal = smoothstep(0.0, 24.0, point.x - 40.0)
		* smoothstep(0.0, 24.0, 415.0 - point.x);
	float vertical = smoothstep(0.0, 14.0, point.y - 440.0)
		* smoothstep(0.0, 24.0, 885.0 - point.y);
	COLOR = texture(TEXTURE, UV) * vec4(1.0, 1.0, 1.0, horizontal * vertical);
}
