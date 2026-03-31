#version 450

#include "./examples/assets/shaders/gen_types.h"

layout(location = 0) in vec2 fragTexCoord;

layout(location = 0) out vec4 outColor;

void main() {
	vec3 color = texture(gTextures2D[getPostprocessingUBO(H0()).texture, fragTexCoord).rgb;
	// outColor = ;
}
