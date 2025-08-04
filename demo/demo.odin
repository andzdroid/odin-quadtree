package demo

import qt "../src"
import "core:log"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

WIDTH :: 1280
HEIGHT :: 800

MAX_NODES :: 1024
MAX_ENTRIES :: 10000
MAX_ENTRIES_PER_NODE :: 1000
MAX_QUERY_RESULTS :: 100

Circle :: struct {
	position: rl.Vector2,
	radius:   f32,
	color:    rl.Color,
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	rl.InitWindow(WIDTH, HEIGHT, "Quadtree Demo")
	defer rl.CloseWindow()

	rl.SetTargetFPS(240)

	tree := new(
		qt.Quadtree(MAX_NODES, MAX_ENTRIES, MAX_ENTRIES_PER_NODE, MAX_QUERY_RESULTS, Circle),
	)
	defer free(tree)

	qt.init(tree, {0, 0, f32(WIDTH), f32(HEIGHT)})

	circles := make([dynamic]Circle)
	defer delete(circles)

	query_mode := 0

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		if rl.IsMouseButtonPressed(.LEFT) {
			circle := Circle {
				position = rl.GetMousePosition(),
				radius   = rand.float32_range(5, 15),
				color    = random_color(),
			}
			rect := qt.Rectangle {
				x      = circle.position.x - circle.radius,
				y      = circle.position.y - circle.radius,
				width  = circle.radius * 2,
				height = circle.radius * 2,
			}
			append(&circles, circle)
			qt.insert(tree, rect, circle)
		}

		if rl.IsMouseButtonPressed(.RIGHT) {
			query_mode = (query_mode + 1) % 3
		}

		for circle in circles {
			rl.DrawCircleV(circle.position, circle.radius, circle.color)
		}

		switch query_mode {
		case 0:
			found := qt.query_point(tree, rl.GetMousePosition().x, rl.GetMousePosition().y)
			for circle in found {
				highlight_circle(circle.data)
			}
		case 1:
			found := qt.query_rectangle(
				tree,
				{
					x = rl.GetMousePosition().x - 50,
					y = rl.GetMousePosition().y - 50,
					width = 100,
					height = 100,
				},
			)
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
			for circle in found {
				highlight_circle(circle.data)
			}
		case 2:
			found := qt.query_circle(tree, rl.GetMousePosition().x, rl.GetMousePosition().y, 50)
			rl.DrawCircleLinesV(rl.GetMousePosition(), 50, rl.RED)
			for circle in found {
				highlight_circle(circle.data)
			}
		}

		node_count := rl.TextFormat("Nodes: %v / %v", tree.node_count, MAX_NODES)
		rl.DrawText(node_count, 10, 10, 20, rl.WHITE)
		entry_count := rl.TextFormat("Entries: %v / %v", tree.entry_count, MAX_ENTRIES)
		rl.DrawText(entry_count, 10, 40, 20, rl.WHITE)

		mode_text := rl.TextFormat("Query Mode: %v", query_mode_text(query_mode))
		rl.DrawText(mode_text, 10, 70, 20, rl.WHITE)
		fps_text := rl.TextFormat("FPS: %d", rl.GetFPS())
		rl.DrawText(fps_text, 10, 100, 20, rl.WHITE)

		instructions := cstring("Left click to add, right click to change query")
		rl.DrawText(instructions, 10, 130, 20, rl.WHITE)

		rl.EndDrawing()
	}
}

random_color :: proc() -> rl.Color {
	return {
		u8(rand.float32_range(50, 255)),
		u8(rand.float32_range(50, 255)),
		u8(rand.float32_range(50, 255)),
		255,
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
		2,
		rl.WHITE,
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
	}
	return ""
}
