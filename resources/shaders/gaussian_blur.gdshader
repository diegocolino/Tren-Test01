shader_type canvas_item;

// Blur gaussiano para depth of field en primer plano
// Usa premultiplied alpha para evitar halos oscuros en bordes transparentes
uniform float blur_radius : hint_range(0.0, 30.0) = 10.0;
uniform int samples : hint_range(4, 32) = 16;
uniform vec4 alarm_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	vec3 rgb_sum = vec3(0.0);
	float alpha_sum = 0.0;
	float weight_sum = 0.0;
	float sigma = blur_radius * 0.5;
	float sigma2 = sigma * sigma;

	for (int x = -samples / 2; x <= samples / 2; x++) {
		for (int y = -samples / 2; y <= samples / 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size * (blur_radius / float(samples / 2));
			float dist2 = float(x * x + y * y);
			float weight = exp(-dist2 / (2.0 * sigma2));
			vec4 s = texture(TEXTURE, UV + offset);
			// Premultiplicar: RGB ponderado por alpha antes de acumular
			rgb_sum += s.rgb * s.a * weight;
			alpha_sum += s.a * weight;
			weight_sum += weight;
		}
	}

	// Deshacer premultiplicación: dividir RGB entre alpha acumulado
	float safe_alpha = max(alpha_sum, 0.001);
	vec3 final_rgb = rgb_sum / safe_alpha;
	float final_alpha = alpha_sum / weight_sum;

	COLOR = vec4(final_rgb * alarm_tint.rgb, final_alpha);
}
