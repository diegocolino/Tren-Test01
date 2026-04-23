shader_type canvas_item;

// Color grading global — tinte atmosférico violáceo-cyan frío
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(0.3, 0.4, 0.55, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.15;
uniform float contrast : hint_range(0.5, 2.0) = 1.1;
uniform float saturation : hint_range(0.0, 2.0) = 0.9;
uniform float lift : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec4 original = texture(screen_texture, SCREEN_UV);
	vec3 color = original.rgb;

	// Saturación
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);

	// Contraste
	color = (color - 0.5) * contrast + 0.5;

	// Lift (subir sombras)
	color = color + lift * (1.0 - color);

	// Tinte
	color = mix(color, tint_color.rgb, tint_strength);

	COLOR = vec4(color, original.a);
}
