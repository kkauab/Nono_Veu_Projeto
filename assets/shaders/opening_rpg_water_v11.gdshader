shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
varying vec2 river_point;
void vertex() { river_point = VERTEX; }
void fragment() {
    vec2 pixel = floor(river_point);
    float phase = floor(clock * 6.0);
    float row = floor(pixel.y / 9.0);
    float drift = floor(sin(row * 1.71 + phase * 0.26) * 4.0);
    float streak = mod(pixel.x + drift + mod(row * 47.0, 91.0), 91.0);
    vec3 water = vec3(0.071, 0.173, 0.204);
    if (mod(floor(pixel.y / 23.0), 2.0) < 1.0) water = vec3(0.078, 0.192, 0.220);
    if (mod(pixel.y, 9.0) < 1.0 && streak < 19.0) water = vec3(0.15, 0.29, 0.31);
    if (mod(pixel.y, 18.0) < 1.0 && streak > 25.0 && streak < 34.0) water = vec3(0.25, 0.41, 0.40);
    COLOR = vec4(water,1.0);
}
