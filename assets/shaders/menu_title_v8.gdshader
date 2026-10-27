shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 dimensions = vec2(textureSize(TEXTURE, 0));
	vec2 pixel = floor(UV * dimensions) + vec2(0.5);
	vec4 original = texture(TEXTURE, pixel / dimensions);
	vec2 sample_pixel = pixel;
	float clock = floor(TIME * 6.0);
	// River only; architecture, sky, lettering and the figure stay anchored.
	bool river = pixel.x > 315.0 && pixel.x < 511.0 && pixel.y > 176.0 && pixel.y < 281.0;
	river = river && pixel.y > 176.0 + max(0.0, 390.0 - pixel.x) * 0.36;
	bool water_color = original.g > original.r * 1.13 && original.b > original.r * 0.93;
	bool reflection = original.r > 0.68 && original.g > 0.46 && original.b < original.g * 0.84;
	if (river && (water_color || reflection)) {
		float current = sin(floor(pixel.y / 3.0) * 0.77 + clock * 0.29);
		sample_pixel.x += floor(current * 1.4);
	}
	// A one-pixel fold movement, restricted to teal cloth inside Senu's cape.
	bool cape = pixel.x > 539.0 && pixel.x < 603.0 && pixel.y > 188.0 && pixel.y < 284.0;
	bool teal = original.g > original.r * 1.10 && original.b > original.r * 0.93;
	if (cape && teal) {
		float sway = sin(clock * 0.25 + floor(pixel.y / 12.0) * 0.5);
		sample_pixel.x += floor(sway * 1.3);
	}
	// The free end of the headband, separate from the face and head.
	bool ribbon = pixel.x > 563.0 && pixel.x < 585.0 && pixel.y > 168.0 && pixel.y < 187.0;
	if (ribbon && original.r > 0.58 && original.g > 0.42) {
		sample_pixel.y += floor(sin(clock * 0.35) * 1.3);
	}
	COLOR = texture(TEXTURE, sample_pixel / dimensions);
}
