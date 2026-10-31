shader_type canvas_item;

// Chão v8 (port_layout.gd, docs/MUNDO_CHAO_V8.md): na borda entre dois temas de
// chão, desenha o tema vizinho por cima em grãos agrupados, do meio a meio na borda
// até sumir dentro do tile. Sem meio-tom: cada pixel do mundo é de um chão ou do outro.
// O limiar junta o Bayer 4×4 em blocos de 2×2 a um sorteio por célula de 4×2, então
// a borda sai em montinhos de areia, não no xadrez pixel a pixel.
// Por vértice: UV.x = índice do tema vizinho, UV.y = quanto dele naquele canto;
// COLOR = a tinta do setor vizinho. A textura é amostrada pela posição no mundo.

uniform sampler2D ground_stone : filter_nearest, repeat_enable;
uniform sampler2D ground_sand : filter_nearest, repeat_enable;
uniform sampler2D ground_wood : filter_nearest, repeat_enable;
uniform sampler2D ground_mosaic : filter_nearest, repeat_enable;
uniform sampler2D ground_garden : filter_nearest, repeat_enable;
uniform sampler2D ground_crypt : filter_nearest, repeat_enable;
uniform sampler2D ground_aqueduct : filter_nearest, repeat_enable;
uniform sampler2D ground_arena : filter_nearest, repeat_enable;
uniform vec2 ground_size = vec2(512.0, 256.0);

varying vec2 world;
varying vec2 blend;

void vertex() {
	world = VERTEX;
	blend = UV;
}

vec4 ground(int theme, vec2 uv) {
	if (theme == 0) return texture(ground_stone, uv);
	if (theme == 1) return texture(ground_sand, uv);
	if (theme == 2) return texture(ground_wood, uv);
	if (theme == 3) return texture(ground_mosaic, uv);
	if (theme == 4) return texture(ground_garden, uv);
	if (theme == 5) return texture(ground_crypt, uv);
	if (theme == 6) return texture(ground_aqueduct, uv);
	return texture(ground_arena, uv);
}

float bayer(vec2 pixel) {
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

float cell_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

float cluster(vec2 pixel) {
	return bayer(floor(pixel / 2.0)) * 0.5 + cell_hash(floor(pixel / vec2(4.0, 2.0))) * 0.5;
}

void fragment() {
	vec2 pixel = floor(world);
	if (blend.y <= cluster(pixel)) {
		discard;
	}
	COLOR = ground(int(round(blend.x)), (pixel + 0.5) / ground_size) * COLOR;
}
