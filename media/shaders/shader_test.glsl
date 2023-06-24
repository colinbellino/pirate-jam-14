#shader vertex
#version 410 core

layout(location = 0) in vec4 vertex_position;

void main() {
    gl_Position = vertex_position;
}

#shader fragment
#version 410 core

uniform vec4 u_color;

out vec4 color;

void main() {
    color = u_color;
}
