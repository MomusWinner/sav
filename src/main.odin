package sav

import sm "core:container/small_array"
import "core:encoding/csv"
import "core:flags"
import "core:fmt"
import "core:log"
import "core:math"
import linalg "core:math/linalg/glsl"
import "core:math/rand"
import "core:os"
import "core:path/slashpath"
import "core:strings"
import "core:time"
import "lib:ve"
import vemath "lib:ve/math"

TARGET_FPS :: 120

// Color palette: https://lospec.com/palette-list/vint-hs 
BACKGROUND := linerize({0.913, 0.964, 0.882})
LINE_COLOR := linerize({0.274, 0.282, 0.278})
TEXT_COLOR := linerize({0.061, 0.061, 0.061})
ROOT_NODE_COLOR := linerize({0.745, 0.0901, 0.2313})
DIR_NODE_COLOR := linerize({0.972, 0.505, 0.184})
FILE_NODE_COLOR := linerize({1, 0.82, 0.25})

CRITICAL_STATUS_NODE_COLOR := linerize({0.745, 0.0901, 0.2313})
MAJOR_STATUS_NODE_COLOR := linerize({0.894, 0.262, 0.149})
NORMAL_STATUS_NODE_COLOR := linerize({0.23, 0.32, 0.8})
MINOR_STATUS_NODE_COLOR := linerize({0.47, 0.49, 0.87})
UNDEFINED_STATUS_NODE_COLOR := linerize({0.329, 0.329, 0.329})

LINE_WIDTH :: 0.03
STATUS_NODE_RADIUS :: 0.3
NODE_RADIUS :: 0.5
ROOT_NODE_RADIUS :: 0.7

LONG_LINE_TARGET_LENGTH :: 17
LONG_LINET_STIFFNESS :: 50
SHORT_LINE_TARGET_LENGTH :: 0.2
SHORT_LINET_STIFFNESS :: 200
DAMPING :: 0.98

COLLIDE_DISTANCE :: 7
COLLIDE_STRENGTH :: 1.5

ROOT_NODE_MASS :: 15
NODE_MASS_C :: 0.6
MIN_NODE_MASS :: 5

vec2 :: vemath.vec2
ivec2 :: vemath.ivec2
uvec2 :: vemath.uvec2
vec3 :: vemath.vec3
ivec3 :: vemath.ivec3
uvec3 :: vemath.uvec3
vec4 :: vemath.vec4
uvec4 :: vemath.uvec4
ivec4 :: vemath.ivec4
mat4 :: vemath.mat4
quat :: vemath.quat

@(buffer)
Base_UBO :: struct {
	color: vec3,
}

Global :: struct {
	square:          ve.Mesh,
	font:            ve.Font,
	circle_pipeline: ve.Graphics_Pipeline,
	base_pipeline:   ve.Graphics_Pipeline,
	text_pipeline:   ve.Graphics_Pipeline,
	line_ubo:        ve.Uniform_Buffer,
	mouse_state:     struct {
		node_id:              int,
		prev_position:        Maybe(vec2),
		prev_camera_position: vec3,
	},
}

g: Global

main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger()
	} else {
		context.logger = log.create_console_logger(lowest = .Warning)
	}
	defer log.destroy_console_logger(context.logger)

	Options :: struct {
		csv: ^os.File `args:"required,file" usage:"CSV file with static analysis output."`,
	}

	opt: Options
	flags.parse_or_exit(&opt, os.args, .Unix)
	defer os.close(opt.csv)

	ve.init(
		{
			gfx = {swapchain_sample_count = ._4, attachments = {.Depth, .Stencil}},
			window = {width = 800, height = 400, floating = true, resizable = true, fullscreen = false, title = "SAV"},
		},
	)

	g.square = ve.create_primitive_square()
	robot_ttf :: #load("../assets/RobotoMono.ttf")
	g.font = ve.load_font(
		robot_ttf,
		{
			size = 80,
			padding = 2,
			atlas_width = 2024,
			atlas_height = 1024,
			regions = {{start = 32, size = 128}, {start = 1024, size = 255}},
			default_char = '?',
		},
	)

	rows := load_csv(opt.csv)
	nodes := create_nodes(rows[:])

	g.line_ubo = create_ubo_base()
	ubo_base_set_color(g.line_ubo, LINE_COLOR)

	g.circle_pipeline = create_circle_pipeline()
	g.base_pipeline = create_base_pipeline()
	g.text_pipeline = create_text_pipeline()

	// uicamera: UICamera
	// init_uicamera(&uicamera)
	camera: ve.Camera
	ve.init_camera(&camera, .Orthographic)
	camera.position = {0.0, 0.0, 1}
	camera.target = {0, 0, 0}
	camera.fov = 20
	camera.near = -5
	camera.far = 5
	camera.zoom = 1

	prev: time.Time
	for !ve.should_close() {
		if (ve.is_key_pressed(.Escape)) {
			break
		}
		when ODIN_DEBUG {
			if (ve.is_key_pressed(.R)) {
				ve.hot_reload_shaders()
			}
		}

		if !ve.screen_resized() {
			update_camera(&camera, 20, 5)
			mouse := screen_to_world_2d(ve.get_mouse_position(), camera)
			if ve.is_mouse_button_down(.Left) {
				if g.mouse_state.node_id == -1 {
					for &n, i in nodes {
						dist := linalg.length_vec2(mouse - n.position)
						if dist < n.radius + 0.1 {
							g.mouse_state.node_id = i
						}
					}
				}
				if g.mouse_state.node_id != -1 {
					nodes[g.mouse_state.node_id].position = mouse
				} else {
					prev, has_prev := g.mouse_state.prev_position.?
					if !has_prev {
						g.mouse_state.prev_position = ve.get_mouse_position()
						g.mouse_state.prev_camera_position = camera.position
					}
				}
			} else {
				g.mouse_state.node_id = -1
				g.mouse_state.prev_position = nil
			}

			update_nodes(nodes[:])
		}

		// set_uicamera(&uicamera)
		ve.set_camera(camera)

		ve.begin_pass()

		ve.begin_draw(vec4{BACKGROUND.x, BACKGROUND.y, BACKGROUND.z, 1})

		// draw refs
		for &n in nodes {
			for i in n.refs {
				r := nodes[i]
				draw_line(n.position, r.position, LINE_WIDTH)
			}
		}

		// draw nodes
		for &n, i in nodes {
			ve.draw_mesh(g.square, g.circle_pipeline, node_get_matrix(n, i, len(nodes)), handles = {h0 = n.ubo})
		}

		// draw texts
		if camera.fov < 70 {
			for &n in nodes {
				text_set_position(&n.text, n.position)
				draw_text(&n.text, g.text_pipeline)
			}
		}

		ve.end_draw()

		ve.end_pass()

		target_delta_time: f64 = (1.0 / TARGET_FPS) * f64(time.Second)
		target_delta_duration := time.Duration(target_delta_time)
		frame_duration := time.diff(prev, time.now())
		if frame_duration < target_delta_duration {
			time.accurate_sleep(target_delta_duration - frame_duration)
		}
		prev = time.now()
	}
}

update_camera :: proc(c: ^ve.Camera, speed: f32, zoom_speed: f32 = 3) {
	c.fov += ve.get_scroll_f32() * zoom_speed
	c.fov = math.clamp(c.fov, 0.5, 100)

	forward := ve.camera_get_forward(c^)

	if ve.is_key_down(.W) {
		c.position.y += speed * ve.get_delta_time()
	}
	if ve.is_key_down(.S) {
		c.position.y -= speed * ve.get_delta_time()
	}
	if ve.is_key_down(.A) {
		c.position.x -= speed * ve.get_delta_time()
	}
	if ve.is_key_down(.D) {
		c.position.x += speed * ve.get_delta_time()
	}

	c.target = c.position + forward
}

draw_line :: proc(start_pos: vec2, end_pos: vec2, width: f32) {
	distance := linalg.length_vec2(end_pos - start_pos)
	trf: ve.Transform
	ve.init_trf(&trf)
	pos := start_pos + (end_pos - start_pos) / 2
	ve.trf_set_position(&trf, {pos.x, pos.y, -1})
	ve.trf_rotate(&trf, {0, 0, 1}, angle_vec2(start_pos, end_pos))
	ve.trf_set_scale(&trf, vec3{distance / 2, width, 1})
	ve.draw_mesh(g.square, g.base_pipeline, ve.trf_get_matrix(trf), {h0 = g.line_ubo})
}

angle_vec2 :: proc(a: vec2, b: vec2) -> f32 {
	c := b - a
	return linalg.atan2_f32(c.y, c.x)
}

Reference_Type :: enum {
	Long,
	Short,
}

Node :: struct {
	name:         string,
	position:     vec2,
	color:        vec3,
	radius:       f32,
	refs:         [dynamic]int,
	ref_types:    [dynamic]Reference_Type,
	mass:         f32,
	velocity:     vec2,
	acceleration: vec2,
	ubo:          ve.Uniform_Buffer,
	text:         Text,
	status:       struct {
		critical:  int,
		major:     int,
		normal:    int,
		minor:     int,
		undefined: int,
	},
}

Status :: struct {
	color: vec3,
	name:  string,
}


create_nodes :: proc(rows: []Row) -> [dynamic]Node {
	add_ref :: proc(n: ^Node, ref: int, type: Reference_Type) {
		append(&n.refs, ref)
		append(&n.ref_types, type)
	}

	nodes := make([dynamic]Node)
	append(
		&nodes,
		Node {
			name = rows[0].package_name,
			position = {0, 0},
			color = ROOT_NODE_COLOR,
			radius = ROOT_NODE_RADIUS,
			mass = ROOT_NODE_MASS,
		},
	)
	root := &nodes[0]

	dir_to_index: map[string]int

	update_node_status_by_criticality :: proc(node: ^Node, criticality: string) {
		switch criticality {
		case "Critical":
			node.status.critical += 1
		case "Major":
			node.status.major += 1
		case "Normal":
			node.status.normal += 1
		case "Minor":
			node.status.minor += 1
		case "Undefined":
			node.status.undefined += 1
		}
	}

	for r in rows {
		elems := strings.split(r.file_name, "/")
		prev_index := -1
		current_dir := make([dynamic]string)
		for e, i in elems {
			append(&current_dir, e)
			dir := slashpath.join(current_dir[:])
			index, ok := dir_to_index[dir]
			if ok {
				prev_index = index
				if i == len(elems) - 1 do update_node_status_by_criticality(&nodes[index], r.criticality)
				continue
			}

			color: vec3 = DIR_NODE_COLOR if i != len(elems) - 1 else FILE_NODE_COLOR
			append(&nodes, Node{name = e, color = color, radius = NODE_RADIUS})
			ni := len(nodes) - 1
			dir_to_index[dir] = ni
			if prev_index != -1 {
				add_ref(&nodes[prev_index], ni, .Long)
			}
			if i == 0 {
				add_ref(root, ni, .Long)
			}
			prev_index = ni
			if i == len(elems) - 1 do update_node_status_by_criticality(&nodes[ni], r.criticality)
		}
	}

	// add status nodes
	for i in 0 ..< len(nodes) {
		n := &nodes[i]
		base := Node {
			position = {0, 0},
			radius   = STATUS_NODE_RADIUS,
		}

		if n.status.critical != 0 {
			status_node := base
			status_node.color = CRITICAL_STATUS_NODE_COLOR
			status_node.name = fmt.aprintf("Crit. %d", n.status.critical)
			append(&nodes, status_node)
			add_ref(n, len(nodes) - 1, .Short)
		}
		if n.status.minor != 0 {
			status_node := base
			status_node.color = MINOR_STATUS_NODE_COLOR
			status_node.name = fmt.aprintf("Minor %d", n.status.minor)
			append(&nodes, status_node)
			add_ref(n, len(nodes) - 1, .Short)
		}
		if n.status.normal != 0 {
			status_node := base
			status_node.color = NORMAL_STATUS_NODE_COLOR
			status_node.name = fmt.aprintf("Norm. %d", n.status.normal)
			append(&nodes, status_node)
			add_ref(n, len(nodes) - 1, .Short)
		}
		if n.status.major != 0 {
			status_node := base
			status_node.color = MAJOR_STATUS_NODE_COLOR
			status_node.name = fmt.aprintf("Major %d", n.status.major)
			append(&nodes, status_node)
			add_ref(n, len(nodes) - 1, .Short)
		}
		if n.status.undefined != 0 {
			status_node := base
			status_node.color = UNDEFINED_STATUS_NODE_COLOR
			status_node.name = fmt.aprintf("Undef. %d", n.status.undefined)
			append(&nodes, status_node)
			add_ref(n, len(nodes) - 1, .Short)
		}
	}

	// init mass
	init_mass :: proc(n_index: int, nodes: []Node) {
		root := nodes[n_index]
		for &r in root.refs {
			nodes[r].mass = root.mass * NODE_MASS_C
			init_mass(r, nodes)
		}
	}
	init_mass(0, nodes[:])

	// init gfx
	for &n in nodes {
		n.ubo = create_ubo_base()
		ubo_base_set_color(n.ubo, n.color)
		n.text = create_text(&g.font, n.name, n.position, TEXT_COLOR, 0.01)
	}

	return nodes
}

update_nodes :: proc(nodes: []Node) {
	for &ni, i in nodes {
		for &nj, j in nodes {
			if i == j do continue
			dist := nj.position - ni.position
			length := linalg.length_vec2(dist)
			if length < COLLIDE_DISTANCE {
				dir: vec2
				if length < 0.001 {
					dir = vec2{rand.float32(), rand.float32()}
					dir = linalg.normalize_vec2(dir)
				} else {
					dir = linalg.normalize_vec2(dist)
				}

				c := 1 - length / COLLIDE_DISTANCE
				c *= COLLIDE_STRENGTH
				force := c * linalg.normalize_vec2(dir) * ve.get_delta_time()
				node_add_force(&ni, -force)
				node_add_force(&nj, force)
			}
		}
	}

	for &n in nodes {
		for r, i in n.refs {
			target_length: f32
			stiffness: f32
			switch n.ref_types[i] {
			case .Long:
				target_length = LONG_LINE_TARGET_LENGTH
				stiffness = LONG_LINET_STIFFNESS
			case .Short:
				target_length = SHORT_LINE_TARGET_LENGTH
				stiffness = SHORT_LINET_STIFFNESS
			}

			end1 := &n
			end2 := &nodes[r]
			x := end1.position - end2.position
			length := linalg.length_vec2(x)
			if length <= target_length do continue
			x = (x / length) * (length - target_length)
			dv := end2.velocity - end1.velocity
			force := (stiffness * x - dv * DAMPING) * ve.get_delta_time()
			node_add_force(end1, -force * ve.get_delta_time())
			node_add_force(end2, force * ve.get_delta_time())
		}
	}

	for &n in nodes {
		n.velocity += n.acceleration
		n.position += n.velocity
		n.acceleration = 0
		if linalg.length_vec2(n.velocity) < 0.001 {
			n.velocity = 0
		}
		n.velocity *= DAMPING
	}

	nodes[0].position = 0
}

node_add_force :: proc(n: ^Node, force: vec2) {
	n.acceleration += force * (1 / n.mass)
}

Row :: struct {
	package_name:  string,
	file_name:     string,
	criticality:   string,
	line:          string,
	function_name: string,
	status:        string,
	comment:       string,
}

load_csv :: proc(f: ^os.File) -> [dynamic]Row {
	stream := os.to_reader(f)
	reader: csv.Reader
	csv.reader_init(&reader, stream)
	head, read_err := csv.read(&reader)

	if read_err != nil do log.panic("Invalid csv file")

	rows := make([dynamic]Row)
	more := true
	for more {
		records, _, err, m := csv.iterator_next(&reader)
		more = m
		if err != nil || len(records) < 7 do break
		append(
			&rows,
			Row {
				package_name = records[0],
				file_name = records[1],
				criticality = records[2],
				line = records[3],
				function_name = records[4],
				status = records[5],
				comment = records[6],
			},
		)
	}

	return rows
}

node_get_matrix :: proc(node: Node, index: int, nodes_length: int) -> mat4 {
	return(
		linalg.mat4Translate(vec3{node.position.x, node.position.y, cast(f32)index / cast(f32)nodes_length}) *
		linalg.mat4Scale(node.radius) \
	)
}

linerize :: proc "contextless" (color: vec3) -> vec3 {
	pow :: proc "contextless" (value: f32) -> f32 {return math.pow_f32(value, 2.2)}
	return vec3{pow(color.x), pow(color.y), pow(color.z)}
}
