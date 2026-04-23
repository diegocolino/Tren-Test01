shader_type canvas_item;

// Motion blur puramente horizontal — estrías de velocidad del tren
uniform float blur_radius : hint_range(0.0, 120.0) = 60.0;
uniform int samples : hint_range(4, 48) = 24;

void fragment() {
	float pixel_w = TEXTURE_PIXEL_SIZE.x;
	vec4 color_sum = vec4(0.0);
	float weight_sum = 0.0;
	float sigma = blur_radius * 0.4;

	for (int i = 0; i < samples; i++) {
		float t = (float(i) / float(samples - 1)) * 2.0 - 1.0; // -1 a 1
		float offset_px = t * blur_radius;
		float weight = exp(-(offset_px * offset_px) / (2.0 * sigma * sigma));
		color_sum += texture(TEXTURE, UV + vec2(offset_px * pixel_w, 0.0)) * weight;
		weight_sum += weight;
	}

	COLOR = color_sum / weight_sum;
}
