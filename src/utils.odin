package sav

import "core:math/linalg/glsl"
import "lib:ve"

screen_to_world_2d :: proc(mouse: vec2, camera: ve.Camera) -> vec2 {
	w, h := cast(f32)ve.get_screen_width(), cast(f32)ve.get_screen_height()
	ndc_x := (2.0 * mouse.x / w) - 1.0
	ndc_y := (2.0 * mouse.y / h) - 1.0

	ndc := vec4{ndc_x, ndc_y, 0.0, 1.0}

	// Inverse projection and view matrices
	inv_proj := glsl.inverse_mat4(ve.camera_get_projection(camera, w / h))
	inv_view := glsl.inverse_mat4(ve.camera_get_view(camera))

	world := inv_view * inv_proj * ndc
	return vec2{world.x, world.y}
}
