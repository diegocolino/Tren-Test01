shader_type canvas_item;
render_mode blend_add;

// Haces de luz cyan por las ventanas del vagón
uniform vec4 light_color : source_color = vec4(0.23, 0.66, 0.77, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.5;
uniform float softness : hint_range(0.0, 1.0) = 0.6;
uniform float falloff : hint_range(0.5, 4.0) = 1.5;

void fragment() {
	float vertical = 1.0 - pow(UV.y, falloff);
	float edge_dist = min(UV.x, 1.0 - UV.x);
	float horizontal = smoothstep(0.0, softness, edge_dist);
	float a = vertical * horizontal * intensity;
	COLOR = vec4(light_color.rgb * a, a);
}
