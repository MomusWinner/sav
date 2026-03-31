package sav

import sm "core:container/small_array"
import "lib:ve"

@(private = "file")
_get_base_create_pipeline_info :: proc() -> ve.Create_Pipeline_Info {
	vert_descriptions: ve.Vertex_Input_Descriptions
	sm.append(&vert_descriptions, ve.create_vertex_input_description())

	return ve.Create_Pipeline_Info {
		bindless = true,
		vertex_input_descriptions = vert_descriptions,
		topology = .Triangle_List,
		rasterizer = {
			polygon_mode = .Fill,
			line_width   = 1,
			cull_mode    = {}, // TODO:
			front_face   = .Counter_Clockwise,
		},
		depth = {
			enable = true,
			write_enable = true,
			compare_op = .Less,
			bounds_test_enable = false,
			min_bounds = 0,
			max_bounds = 0,
		},
	}
}

@(private = "file")
_get_blending_infos :: proc() -> ve.Blending_Infos {
	bleding := ve.Blending_Infos{}
	sm.append(
		&bleding,
		ve.Blending_Info {
			src_color_blend_factor = .Src_Alpha,
			dst_color_blend_factor = .One_Minus_Src_Alpha,
			color_blend_op = .Add,
			src_alpha_blend_factor = .One,
			dst_alpha_blend_factor = .Zero,
			alpha_blend_op = .Add,
			color_write_mask = {.R, .G, .B, .A},
		},
	)
	return bleding
}

create_circle_pipeline :: proc() -> ve.Graphics_Pipeline {
	stages := ve.Stage_Infos{}

	when !ODIN_DEBUG {
		vert := #load("../shaders/circle.vert.spv")
		frag := #load("../shaders/circle.frag.spv")
		sm.push_back_elems(
			&stages,
			ve.Pipeline_Stage_Info{stage = .Vertex, source = vert},
			ve.Pipeline_Stage_Info{stage = .Fragment, source = frag},
		)
	} else {
		sm.push_back_elems(
			&stages,
			ve.Pipeline_Stage_Info{stage = .Vertex, source = "shaders/circle.vert"},
			ve.Pipeline_Stage_Info{stage = .Fragment, source = "shaders/circle.frag"},
		)
	}

	create_info := _get_base_create_pipeline_info()
	create_info.stage_infos = stages
	create_info.blending_info.attachment_infos = _get_blending_infos()

	return ve.create_graphics_pipeline(create_info)
}

create_base_pipeline :: proc() -> ve.Graphics_Pipeline {
	stages := ve.Stage_Infos{}

	when !ODIN_DEBUG {
		vert := #load("../shaders/base.vert.spv")
		frag := #load("../shaders/base.frag.spv")
		sm.push_back_elems(
			&stages,
			ve.Pipeline_Stage_Info{stage = .Vertex, source = vert},
			ve.Pipeline_Stage_Info{stage = .Fragment, source = frag},
		)
	} else {
		sm.push_back_elems(
			&stages,
			ve.Pipeline_Stage_Info{stage = .Vertex, source = "shaders/base.vert"},
			ve.Pipeline_Stage_Info{stage = .Fragment, source = "shaders/base.frag"},
		)
	}

	create_info := _get_base_create_pipeline_info()
	create_info.stage_infos = stages
	create_info.blending_info.attachment_infos = _get_blending_infos()

	return ve.create_graphics_pipeline(create_info)
}

create_text_pipeline :: proc() -> ve.Graphics_Pipeline {
	vert_descriptions: ve.Vertex_Input_Descriptions
	sm.append(&vert_descriptions, text_shader_attribute())


	stages := ve.Stage_Infos{}
	when !ODIN_DEBUG {
		text_vert := #load("../shaders/text.vert.spv")
		text_frag := #load("../shaders/text.frag.spv")
		sm.push_back_elems(
			&stages,
			ve.Pipeline_Stage_Info{stage = .Vertex, source = text_vert},
			ve.Pipeline_Stage_Info{stage = .Fragment, source = text_frag},
		)
	} else {
		sm.push_back_elems(
			&stages,
			ve.Pipeline_Stage_Info{stage = .Vertex, source = "shaders/text.vert"},
			ve.Pipeline_Stage_Info{stage = .Fragment, source = "shaders/text.frag"},
		)
	}

	create_info := ve.Create_Pipeline_Info {
		bindless = true,
		vertex_input_descriptions = vert_descriptions,
		blending_info = {attachment_infos = _get_blending_infos()},
		stage_infos = stages,
		topology = .Triangle_List,
		rasterizer = {
			polygon_mode = .Fill,
			line_width   = 1,
			cull_mode    = {}, //TODO: 
			front_face   = .Clockwise,
		},
		depth = {
			enable = true,
			write_enable = true,
			compare_op = .Less,
			bounds_test_enable = false,
			min_bounds = 0,
			max_bounds = 0,
		},
		stencil = {enable = false},
	}

	return ve.create_graphics_pipeline(create_info)
}
