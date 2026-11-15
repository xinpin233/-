shader_type canvas_item;

uniform vec2 center = vec2(0.5);
uniform vec2 radius = vec2(0.1);

void fragment() {
	vec2 local = (UV - center) / radius;
	vec4 art = texture(TEXTURE, UV);
	float mask = 1.0 - smoothstep(0.48, 1.0, length(local));
	COLOR = vec4(art.rgb, art.a * mask);
}