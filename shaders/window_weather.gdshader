shader_type canvas_item;
uniform vec4 daylight : source_color = vec4(1.0);
uniform float weather = 0.0;
uniform float motion_time = 0.0;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec3 graded = source.rgb * daylight.rgb;
	bool column = (UV.x > 0.134 && UV.x < 0.289) || (UV.x > 0.316 && UV.x < 0.477) || (UV.x > 0.527 && UV.x < 0.689) || (UV.x > 0.717 && UV.x < 0.866);
	bool glass = column && (UV.y < 0.383 || (UV.y > 0.424 && UV.y < 0.658));
	if (weather > 0.5 && glass) {
		float cloud = 0.5 + 0.5 * sin(motion_time * 0.095 + UV.x * 2.0);
		graded *= 0.97 - cloud * 0.055;
		if (weather > 1.5) {
			graded = mix(graded, vec3(dot(graded, vec3(0.299, 0.587, 0.114))), 0.17);
			vec2 grid = UV * vec2(110.0, 32.0);
			vec2 cell = floor(grid);
			float seed = hash(cell);
			float trail = fract(grid.y - motion_time * (0.55 + hash(vec2(cell.x, 8.0)) * 0.5));
			float across = abs(fract(grid.x + trail * 0.07) - 0.25 - hash(vec2(cell.x, 3.0)) * 0.5);
			float streak = (1.0 - smoothstep(0.015, 0.055, across)) * (1.0 - smoothstep(0.02, 0.33, trail));
			float opacity = streak * (0.15 + seed * 0.18);
			graded = mix(graded, vec3(0.75, 0.77, 0.71), opacity);
		}
	}
	COLOR = vec4(graded, source.a);
}
