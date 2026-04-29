shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 original = texture(screen_texture, SCREEN_UV);
	float luma = dot(original.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gray = vec3(luma);
	COLOR = vec4(mix(original.rgb, gray, intensity), original.a);
}
