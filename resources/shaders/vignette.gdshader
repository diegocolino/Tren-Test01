shader_type canvas_item;

// Viñeta para oscurecimiento sutil de bordes
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float vignette = smoothstep(vignette_softness, 1.0, dist * 2.0);
	COLOR = mix(vec4(0.0), vignette_color, vignette * vignette_intensity);
}
