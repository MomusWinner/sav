#version 450

#include "./shaders/gen_types.h"

layout(location = 0) in vec2 fragTexCoord;

layout(location = 0) out vec4 outColor;

void main() {
	float len = length(fragTexCoord - vec2(0.5, 0.5));
	if (len < 0.4) {
		outColor = vec4(getBaseUBO(H0()).color,1);
	} else if (len < 0.5) {
		outColor = vec4(getBaseUBO(H0()).color, 1 - (len - 0.4) / 0.1);
	} else {
		outColor = vec4(0,0,0,0);
	}
}
