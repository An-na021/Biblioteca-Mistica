shader_type canvas_item;

uniform float remaining : hint_range(0.0, 1.0) = 1.0;
uniform vec4 glow_tint : source_color = vec4(0.76, 0.86, 0.56, 1.0);

varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Only the green glass changes; bronze, slate, gears and ruby keep their paint.
	vec2 delta = UV - vec2(0.499, 0.510);
	float radius = length(delta);
	float glass = smoothstep(0.245, 0.255, radius) * (1.0 - smoothstep(0.300, 0.315, radius));
	glass *= smoothstep(0.015, 0.075, source.g - source.r);
	glass *= smoothstep(0.025, 0.10, source.g - source.b);
	float angle = mod(atan(delta.x, -delta.y + 0.000001) + TAU, TAU) / TAU;
	float active = (1.0 - smoothstep(remaining - 0.001, remaining + 0.002, angle)) * step(0.00001, remaining);
	float light = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 lit = glow_tint.rgb * (0.4 + light * 0.8);
	vec3 unlit = source.rgb * vec3(0.25, 0.26, 0.30);
	source.rgb = mix(source.rgb, mix(unlit, lit, active), glass);
	COLOR = source * item_tint;
}
