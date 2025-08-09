package demo

import qt "../src"
import "core:log"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

WIDTH :: 1280
HEIGHT :: 800

MAX_NODES :: 1001
MAX_ENTRIES :: 10000
MAX_QUERY_RESULTS :: 100

Color :: enum {
	Red,
	Green,
	Blue,
}

ColorValues :: [Color]rl.Color {
	.Red   = {200, 60, 30, 255},
	.Green = {60, 200, 30, 255},
	.Blue  = {30, 60, 200, 255},
}

Circle :: struct {
	position:  rl.Vector2,
	direction: rl.Vector2,
	speed:     f32,
	radius:    f32,
	color:     Color,
	index:     int,
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	rl.InitWindow(WIDTH, HEIGHT, "Quadtree Demo")
	defer rl.CloseWindow()

	rl.SetTargetFPS(240)

	tree := new(qt.Quadtree(MAX_NODES, MAX_ENTRIES, MAX_QUERY_RESULTS, int))
	defer free(tree)

	qt.init(tree, {0, 0, f32(WIDTH), f32(HEIGHT)})

	circles := new([MAX_ENTRIES]Circle)
	defer free(circles)

	circle_count := 0
	query_mode := 0
	colors := ColorValues

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		if rl.IsMouseButtonPressed(.LEFT) {
			// spawn 100 circles
			for i in 0 ..< 100 {
				circle_index := circle_count
				circle_count += 1

				circle := Circle {
					position  = rl.GetMousePosition(),
					direction = {rand.float32_range(-1, 1), rand.float32_range(-1, 1)},
					speed     = rand.float32_range(20, 150),
					radius    = rand.float32_range(5, 15),
					color     = Color(rl.GetRandomValue(0, 2)),
				}
				rect := qt.Rectangle {
					x      = circle.position.x - circle.radius,
					y      = circle.position.y - circle.radius,
					width  = circle.radius * 2,
					height = circle.radius * 2,
				}
				circle.index, _ = qt.insert(tree, rect, circle_index)
				circles[circle_index] = circle
			}
		}

		if rl.IsMouseButtonPressed(.RIGHT) {
			query_mode = (query_mode + 1) % 6
		}

		// Draw quadtree
		for i in 0 ..< tree.node_count {
			rl.DrawRectangleLinesEx(rl.Rectangle(tree.nodes[i].bounds), 0.5, {255, 255, 255, 64})
		}

		dt := rl.GetFrameTime()

		// Update and draw circles
		for i in 0 ..< circle_count {
			circle := &circles[i]

			circle.position += circle.direction * dt * circle.speed
			if circle.position.x < circle.radius + 1 ||
			   circle.position.x > f32(WIDTH) - circle.radius - 1 {
				circle.direction.x *= -1
				circle.position.x = math.clamp(
					circle.position.x,
					circle.radius + 1,
					f32(WIDTH) - circle.radius - 1,
				)
			}
			if circle.position.y < circle.radius + 1 ||
			   circle.position.y > f32(HEIGHT) - circle.radius - 1 {
				circle.direction.y *= -1
				circle.position.y = math.clamp(
					circle.position.y,
					circle.radius + 1,
					f32(HEIGHT) - circle.radius - 1,
				)
			}

			circle_index, ok := qt.update(
				tree,
				circle.index,
				{
					x = circle.position.x - circle.radius,
					y = circle.position.y - circle.radius,
					width = circle.radius * 2,
					height = circle.radius * 2,
				},
				i,
			)

			color :=
				query_mode < 3 || circle.color == .Red ? colors[circle.color] : {200, 200, 200, 255}
			rl.DrawCircleV(circle.position, circle.radius, color)
		}

		switch query_mode {
		case 0:
			results := qt.query_point(tree, rl.GetMousePosition().x, rl.GetMousePosition().y)
			for result in results {
				highlight_circle(circles[result.data])
			}
		case 1:
			results := qt.query_rectangle(
				tree,
				{
					x = rl.GetMousePosition().x - 50,
					y = rl.GetMousePosition().y - 50,
					width = 100,
					height = 100,
				},
			)
			for result in results {
				highlight_circle(circles[result.data])
			}
			rl.DrawRectangleLinesEx(
				{
					x = rl.GetMousePosition().x - 50,
					y = rl.GetMousePosition().y - 50,
					width = 100,
					height = 100,
				},
				2,
				rl.RED,
			)
		case 2:
			results := qt.query_circle(tree, rl.GetMousePosition().x, rl.GetMousePosition().y, 75)
			for result in results {
				highlight_circle(circles[result.data])
			}
			rl.DrawCircleLinesV(rl.GetMousePosition(), 75, rl.RED)
		case 3:
			// only search for red circles
			// if you need to pass data into the predicate, you can use context.user_ptr
			context.user_ptr = circles
			results := qt.query_rectangle(
				tree,
				{
					x = rl.GetMousePosition().x - 75,
					y = rl.GetMousePosition().y - 75,
					width = 150,
					height = 150,
				},
				qt.QueryRectangleOptions(int) {
					predicate = proc(entry: qt.Entry(int)) -> bool {
						circles := cast(^[MAX_ENTRIES]Circle)context.user_ptr
						circle := circles[entry.data]
						return circle.color == .Red
					},
				},
			)
			for result in results {
				highlight_circle(circles[result.data])
			}
			rl.DrawRectangleLinesEx(
				{
					x = rl.GetMousePosition().x - 75,
					y = rl.GetMousePosition().y - 75,
					width = 150,
					height = 150,
				},
				2,
				rl.RED,
			)
		case 4:
			context.user_ptr = circles
			results := qt.query_circle(
				tree,
				rl.GetMousePosition().x,
				rl.GetMousePosition().y,
				75,
				qt.QueryCircleOptions(int) {
					predicate = proc(entry: qt.Entry(int)) -> bool {
						circles := cast(^[MAX_ENTRIES]Circle)context.user_ptr
						circle := circles[entry.data]
						return circle.color == .Red
					},
				},
			)
			for result in results {
				highlight_circle(circles[result.data])
			}
			rl.DrawCircleLinesV(rl.GetMousePosition(), 75, rl.RED)
		case 5:
			context.user_ptr = circles
			results := qt.query_nearest(
				tree,
				rl.GetMousePosition().x,
				rl.GetMousePosition().y,
				qt.QueryNearestOptions(int) {
					max_results = 3,
					max_distance = 300,
					predicate = proc(entry: qt.Entry(int)) -> bool {
						circles := cast(^[MAX_ENTRIES]Circle)context.user_ptr
						circle := circles[entry.data]
						return circle.color == .Red
					},
				},
			)
			for result in results {
				highlight_circle(circles[result.data])
			}
		}

		instructions := cstring("Left click to add, right click to change query")
		instructions_width := rl.MeasureText(instructions, 20)
		rl.DrawRectangle(0, 0, instructions_width + 20, 160, {0, 0, 0, 200})

		node_count := rl.TextFormat("Nodes: %v / %v", tree.node_count, MAX_NODES)
		rl.DrawText(node_count, 10, 10, 20, rl.WHITE)
		entry_count := rl.TextFormat("Entries: %v / %v", tree.entry_count, MAX_ENTRIES)
		rl.DrawText(entry_count, 10, 40, 20, rl.WHITE)

		mode_text := rl.TextFormat("Query Mode: %v", query_mode_text(query_mode))
		rl.DrawText(mode_text, 10, 70, 20, rl.WHITE)
		fps_text := rl.TextFormat("FPS: %d", rl.GetFPS())
		rl.DrawText(fps_text, 10, 100, 20, rl.WHITE)

		rl.DrawText(instructions, 10, 130, 20, rl.WHITE)

		rl.EndDrawing()
	}
}

highlight_circle :: proc(circle: Circle) {
	rl.DrawRectangleLinesEx(
		{
			x = circle.position.x - circle.radius - 1,
			y = circle.position.y - circle.radius - 1,
			width = circle.radius * 2 + 2,
			height = circle.radius * 2 + 2,
		},
		1,
		rl.YELLOW,
	)
}

query_mode_text :: proc(mode: int) -> string {
	switch mode {
	case 0:
		return "Point"
	case 1:
		return "Rectangle"
	case 2:
		return "Circle"
	case 3:
		return "Rectangle (only red)"
	case 4:
		return "Circle (only red)"
	case 5:
		return "Nearest 3 red circles"
	}
	return ""
}
