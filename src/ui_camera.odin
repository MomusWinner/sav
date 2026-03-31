package sav

import lin "core:math/linalg/glsl"
import "lib:ve"
import "lib:ve/math"

@(buffer)
Camera_UBO :: struct {
	view:       mat4,
	projection: mat4,
	position:   vec3,
}

UICamera :: struct {
	ubo:      ve.Uniform_Buffer, // Camera_UBO
	position: vec3,
}

init_uicamera :: proc(c: ^UICamera) {
	c.ubo = create_ubo_camera()
	c.position.z = -1
}

uicamera_set_pos :: proc(c: ^UICamera, pos: vec2) {
	c.position.xy = pos
}

set_uicamera :: proc(c: ^UICamera) {
	projection := math.ortho(0, cast(f32)ve.get_screen_width(), cast(f32)ve.get_screen_height(), 0, -1.0, 1.0)
	ubo_camera_set_projection(c.ubo, projection)
	// ubo_camera_set_view(c.ubo, _uicamera_get_view(c))
	// ubo_camera_set_position(c.ubo, c.position)
	// ubo_camera_set_projection(c.ubo, 1)
	ubo_camera_set_view(c.ubo, 1)
	ubo_camera_set_position(c.ubo, {})
	ve.set_camera_buffer(ve.ubo_get_buffer(c.ubo))
}

@(private = "file")
_uicamera_get_view :: proc(c: ^UICamera) -> mat4 {
	return lin.mat4LookAt(c.position, c.position + {0, 0, 1}, {0, 1, 0})
	// * lin.mat4Scale(camera.zoom) \
}
