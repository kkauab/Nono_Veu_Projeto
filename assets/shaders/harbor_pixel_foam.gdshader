shader_type canvas_item;
render_mode unshaded;
varying vec2 shore_position;
void vertex() { shore_position = VERTEX; }
void fragment() {
    float phase = floor(TIME * 6.0);
    float shimmer = step(0.55, sin(floor(shore_position.x / 5.0) * 1.7 + floor(shore_position.y / 3.0) * 0.9 + phase * 0.6));
    COLOR = vec4(vec3(0.38, 0.57, 0.54), 0.18 + shimmer * 0.32);
}
