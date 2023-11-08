#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_color;
layout(location = 2) in vec2 i_texture_coordinates;
layout(location = 3) in float i_texture_index;
layout(location = 4) in float i_palette_index;
uniform mat4 u_model_view_projection;
out vec4 v_color;
out vec2 v_texture_coordinates;
out float v_texture_index;
out float v_palette_index;

void main() {
    gl_Position = u_model_view_projection * i_position;
    v_color = i_color;
    v_texture_coordinates = i_texture_coordinates;
    v_texture_index = i_texture_index;
    v_palette_index = i_palette_index;
}

#shader fragment
#version 410 core

#define resolution vec2(640, 360)
#define Thickness 0.005

float draw_line(vec2 p1, vec2 p2) {
  vec2 uv = gl_FragCoord.xy / resolution.xy;

  float a = abs(distance(p1, uv));
  float b = abs(distance(p2, uv));
  float c = abs(distance(p1, p2));

  if ( a >= c || b >=  c ) {
    return 0.0;
  }

  float p = (a + b + c) * 0.5;

  // median to (p1, p2) vector
  float h = 2 / c * sqrt( p * ( p - a) * ( p - b) * ( p - c));

  return mix(1.0, 0.0, smoothstep(0.5 * Thickness, 1.5 * Thickness, h));
}

void main()
{
    vec2 point1 = vec2(2, 1);
    vec2 point2 = vec2(2, 2);
    vec2 point3 = vec2(1, 1);

    gl_FragColor = vec4(
        max(
            max(draw_line(point1, point2), draw_line(point2, point3)),
            draw_line(point1, point3)
        )
    );
}
