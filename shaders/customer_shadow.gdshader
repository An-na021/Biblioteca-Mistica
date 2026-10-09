shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.12, 0.075, 0.04, 0.30);
uniform vec2 shadow_offset = vec2(0.012, 0.018);
uniform float blur_radius : hint_range(0.0, 0.02) = 0.007;

void fragment() {
	vec2 uv = UV - shadow_offset;
	vec2 blur = TEXTURE_PIXEL_SIZE * (blur_radius * 512.0);
	float alpha = texture(TEXTURE, uv).a * 0.25;
	alpha += texture(TEXTURE, uv + vec2(blur.x, 0.0)).a * 0.125;
	alpha += texture(TEXTURE, uv - vec2(blur.x, 0.0)).a * 0.125;
	alpha += texture(TEXTURE, uv + vec2(0.0, blur.y)).a * 0.125;
	alpha += texture(TEXTURE, uv - vec2(0.0, blur.y)).a * 0.125;
	alpha += texture(TEXTURE, uv + blur).a * 0.0625;
	alpha += texture(TEXTURE, uv - blur).a * 0.0625;
	alpha += texture(TEXTURE, uv + vec2(blur.x, -blur.y)).a * 0.0625;
	alpha += texture(TEXTURE, uv + vec2(-blur.x, blur.y)).a * 0.0625;
	COLOR = vec4(shadow_color.rgb, shadow_color.a * alpha * COLOR.a);
}
