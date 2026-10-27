shader_type canvas_item;
render_mode unshaded;
varying vec2 water_position;
void vertex() { water_position = VERTEX; }
void fragment() {
    // Eight Pixelorama cels; one surface and no CPU redraw loop.
    float tick = floor(TIME * 8.0);
    float frame = 44.0 + mod(tick, 8.0);
    vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0)) * 192.0;
    vec2 current = floor(water_position + vec2(floor(tick / 4.0), floor(tick / 9.0)));
    vec2 pixel = mod(current, vec2(128.0));
    vec2 atlas_uv = (cell + vec2(32.0) + pixel + vec2(0.5)) / vec2(textureSize(TEXTURE, 0));
    COLOR = texture(TEXTURE, atlas_uv);
}
