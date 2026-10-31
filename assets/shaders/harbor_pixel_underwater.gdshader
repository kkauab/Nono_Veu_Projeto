shader_type canvas_item;
render_mode unshaded;

// Mergulho (sea_dive.gd): tudo o que se vê embaixo d'água passa por aqui. A água
// come o vermelho, puxa as cores de terra para o verde-azulado do porto e
// escurece com a distância do chão (sea_depth.gd), em faixas de grão agrupado.
// A luz da superfície desenha cáusticas em blocos de 2 px, a 8 quadros por segundo:
// a rede de linhas entre células de Voronoi que se movem devagar, como a luz que
// a ondulação concentra no fundo.

uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec2 depth_origin = vec2(0.0);
uniform vec2 depth_size = vec2(0.0);
// 1 no fundo; as silhuetas da superfície e as bolhas usam 0 (sem cáustica).
uniform float caustics = 1.0;
const float MAX_DEPTH = 8.0;

varying vec2 world;

void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec2 cell_point(vec2 cell, float t) {
    vec2 seed = fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
    return cell + 0.5 + 0.38 * sin(t * 0.9 + seed * 6.2831);
}

// Diferença entre a segunda e a primeira distância a um ponto: perto de 0 nas
// fronteiras entre células, que viram as linhas de luz.
float caustic_edge(vec2 p, float t) {
    vec2 cell = floor(p);
    float first = 9.0;
    float second = 9.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 near = cell + vec2(float(x), float(y));
            float d = distance(p, cell_point(near, t));
            if (d < first) {
                second = first;
                first = d;
            } else if (d < second) {
                second = d;
            }
        }
    }
    return second - first;
}

float cluster(vec2 pixel) {
    int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
    vec2 block = floor(pixel / 2.0);
    int x = int(mod(block.x, 4.0));
    int y = int(mod(block.y, 4.0));
    return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
    vec4 color = texture(TEXTURE, UV) * COLOR;
    vec2 spot = floor(world);
    float depth = MAX_DEPTH;
    if (depth_size.x > 0.0) {
        vec2 tile = vec2(spot.x / 64.0 + spot.y / 32.0, spot.y / 32.0 - spot.x / 64.0);
        depth = texture(depth_map, (tile - depth_origin + 0.5) / depth_size).r * MAX_DEPTH;
    }
    float deep = clamp(depth / MAX_DEPTH, 0.0, 1.0);
    vec3 absorbed = color.rgb * vec3(0.5, 0.84, 0.88);
    vec3 water = vec3(0.06, 0.19, 0.22);
    float fog = floor((0.18 + deep * 0.42) * 6.0 + cluster(spot)) / 6.0;
    vec3 graded = mix(absorbed, water, fog);
    float t = floor(TIME * 8.0) / 8.0;
    // Células de 40×20 px (achatadas como o chão isométrico).
    vec2 p = floor(world / 2.0) * 2.0 / vec2(40.0, 20.0);
    float edge = caustic_edge(p, t);
    float light = step(edge, 0.045) * (1.0 - deep * 0.75) * caustics;
    graded += vec3(0.045, 0.08, 0.07) * light;
    COLOR = vec4(graded, color.a);
}
