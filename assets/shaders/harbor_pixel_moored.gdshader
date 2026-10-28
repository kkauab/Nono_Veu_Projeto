shader_type canvas_item;
// Navio ancorado (scripts/world/sea.gd). Sem isto o casco aparecia inteiro, com
// contorno e sombra embaixo, e o navio parecia pairar sobre a água. Aqui os
// últimos pixels do casco ficam dentro d'água, a linha d'água ondula e o navio
// balança 1 pixel. Tudo em pixels inteiros, para não borrar o pixel art.

// Pé do casco em cada coluna da arte (port_art.gd, art_bottom): (y + 176) / 255.
uniform sampler2D hull_bottom : filter_nearest;
// Quantos pixels do casco ficam submersos.
uniform float depth = 7.0;
// Defasagem própria de cada navio, para não balançarem juntos.
uniform float phase = 0.0;
uniform vec4 water : source_color = vec4(0.11, 0.24, 0.27, 1.0);
uniform vec4 foam : source_color = vec4(0.80, 0.90, 0.86, 1.0);

varying vec2 local;
varying float bob;

void vertex() {
	local = VERTEX;
	bob = floor(sin(TIME * 1.1 + phase) * 1.4 + 0.5);
	VERTEX.y += bob;
}

void fragment() {
	float column = floor(local.x) + 96.0;
	float bottom = floor(texture(hull_bottom, vec2((column + 0.5) / 192.0, 0.5)).r * 255.0 + 0.5) - 176.0;
	float swell = floor(sin(TIME * 1.7 + floor(local.x / 3.0) * 0.8 + phase) * 0.9 + 0.5);
	// A superfície fica parada no mundo; o casco é que sobe e desce.
	float surface = bottom - depth + swell - bob;
	float under = floor(local.y) - surface;
	if (COLOR.a > 0.0 && under >= 0.0) {
		float t = clamp(under / depth, 0.0, 1.0);
		COLOR.rgb = mix(COLOR.rgb, water.rgb, 0.55 + 0.4 * t);
		COLOR.a *= 0.8 - 0.55 * t;
		if (under < 1.0) {
			COLOR = vec4(foam.rgb, 0.85);
		}
	}
}
