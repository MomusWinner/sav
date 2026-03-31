#version 450

#include "./shaders/gen_types.h"

layout(location = 0) in vec2 fragTexCoord;

layout(location = 0) out vec4 outColor;

void main() {
	outColor = vec4(getBaseUBO(H0()).color,1);
}
