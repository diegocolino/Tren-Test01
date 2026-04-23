shader_type canvas_item;
render_mode blend_mix;

uniform vec4 alarm_color : source_color = vec4(1.0, 0.25, 0.125, 1.0);
uniform float min_intensity = 0.08;
uniform float max_intensity = 0.5;
uniform float pulse_frequency = 0.4;  // Hz
uniform float edge_softness = 0.35;   // qué tan periférico (0.1 = muy borde, 0.5 = invade más)
uniform float asymmetry = 0.3;        // 0 = sinusoidal puro, 1 = muy asimétrico

void fragment() {
	// Distancia del pixel al centro, normalizada (0 centro, 1 esquinas)
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.77;  // aspect ratio compensation para 16:9
	float dist = length(uv);

	// Máscara periférica: solo aparece cerca de los bordes
	float edge_mask = smoothstep(0.5 - edge_softness, 0.85, dist);

	// Curva de pulso asimétrica
	float t = TIME * pulse_frequency * TAU;
	float raw_pulse = 0.5 + 0.5 * sin(t);

	// Asimetría: eleva a una potencia para hacer el sostén y caída distintos
	float pulse = pow(raw_pulse, 1.0 + asymmetry * 2.0);

	// Intensidad final
	float intensity = mix(min_intensity, max_intensity, pulse);

	// Color final aplicado solo en la máscara
	float alpha = edge_mask * intensity;
	COLOR = vec4(alarm_color.rgb, alpha);
}
