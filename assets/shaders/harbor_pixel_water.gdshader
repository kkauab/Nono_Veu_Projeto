shader_type canvas_item;
render_mode unshaded;

// Mapa de profundidade (sea_depth.gd): um pixel por tile, 0 no chão e 1 a
// MAX_DEPTH tiles dele. Sem mapa, a água inteira é funda, como antes.
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec2 depth_origin = vec2(0.0);
uniform vec2 depth_size = vec2(0.0);
const float MAX_DEPTH = 8.0;

varying vec2 water_position;
void vertex() { water_position = VERTEX; }

// Limiar em grãos de 2×2 px (Bayer 4×4 em blocos), como as bordas do chão v8.
float cluster(vec2 pixel) {
    int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
    vec2 block = floor(pixel / 2.0);
    int x = int(mod(block.x, 4.0));
    int y = int(mod(block.y, 4.0));
    return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
    // Eight Pixelorama cels; one surface and no CPU redraw loop.
    float tick = floor(TIME * 8.0);
    float frame = 44.0 + mod(tick, 8.0);
    vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0)) * 192.0;
    // Deriva em passos de 1 px junto com a troca de quadro. Antes eram 2 px/s
    // em x e menos de 1 px/s em y: um tranco a cada meio segundo, ampliado 2x.
    vec2 current = floor(water_position + vec2(floor(tick / 2.0), floor(tick / 5.0)));
    // O recorte de 128 px do quadro não fecha nas bordas: repetido, deixava emendas
    // retas a cada 128 px. Espelhado a cada repetição, ele continua sem corte.
    vec2 period = mod(current, vec2(256.0));
    vec2 pixel = mix(period, vec2(255.0) - period, step(vec2(128.0), period));
    vec2 atlas_uv = (cell + vec2(32.0) + pixel + vec2(0.5)) / vec2(textureSize(TEXTURE, 0));
    vec4 color = texture(TEXTURE, atlas_uv);
    if (depth_size.x > 0.0) {
        // Água rasa perto do chão: mais clara e esverdeada, em duas faixas de grão
        // agrupado, nada de degradê liso.
        vec2 spot = floor(water_position);
        vec2 tile = vec2(spot.x / 64.0 + spot.y / 32.0, spot.y / 32.0 - spot.x / 64.0);
        float depth = texture(depth_map, (tile - depth_origin + 0.5) / depth_size).r * MAX_DEPTH;
        float grain = cluster(spot);
        float shallow = step(grain, 1.0 - smoothstep(0.9, 2.1, depth));
        float middle = step(grain, 1.0 - smoothstep(2.1, 3.6, depth));
        vec3 lifted = color.rgb * vec3(1.16, 1.3, 1.2) + vec3(0.02, 0.045, 0.035);
        color.rgb = mix(color.rgb, lifted, max(shallow * 0.75, middle * 0.35));
    }
    COLOR = color;
}
