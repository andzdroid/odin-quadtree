package quadtree

import "core:testing"

@(test)
test_quadtree_creation :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)
	testing.expect(t, tree.nodes[0].bounds == bounds, "Root bounds should match")
}

@(test)
test_point_insertion :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	p1 := Rectangle{25, 25, 10, 10}
	p2 := Rectangle{75, 75, 10, 10}

	testing.expect(t, insert(&tree, p1, 1), "Should insert point within bounds")
	testing.expect(t, insert(&tree, p2, 2), "Should insert second point")
	testing.expect(t, tree.nodes[0].size == 2, "Root should have 2 points")
}

@(test)
test_subdivision :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{25, 25, 10, 10}, 1)
	insert(&tree, Rectangle{75, 25, 10, 10}, 2)
	insert(&tree, Rectangle{25, 75, 10, 10}, 3)
	insert(&tree, Rectangle{75, 75, 10, 10}, 4)
	insert(&tree, Rectangle{45, 45, 10, 10}, 5)

	testing.expect(t, tree.nodes[0].divided, "Should subdivide")
	testing.expect(t, tree.nodes[0].size == 1, "Root should have 1 entry after subdivision")

	nw := tree.nodes[0].children[0]
	ne := tree.nodes[0].children[1]
	sw := tree.nodes[0].children[2]
	se := tree.nodes[0].children[3]

	testing.expect(t, tree.nodes[nw].size == 1, "NW should have 1 entry")
	testing.expect(t, tree.nodes[ne].size == 1, "NE should have 1 entry")
	testing.expect(t, tree.nodes[sw].size == 1, "SW should have 1 entry")
	testing.expect(t, tree.nodes[se].size == 1, "SE should have 1 entry")

	nw_node := &tree.nodes[nw]
	ne_node := &tree.nodes[ne]
	sw_node := &tree.nodes[sw]
	se_node := &tree.nodes[se]
	root_node := &tree.nodes[0]

	nw_data := tree.entries[nw_node.entries[0]]
	ne_data := tree.entries[ne_node.entries[0]]
	sw_data := tree.entries[sw_node.entries[0]]
	se_data := tree.entries[se_node.entries[0]]
	root_data := tree.entries[root_node.entries[0]]

	testing.expect(
		t,
		nw_data.rect == Rectangle{25, 25, 10, 10} && nw_data.data == 1,
		"Rect {25,25,10,10} in NW",
	)
	testing.expect(
		t,
		ne_data.rect == Rectangle{75, 25, 10, 10} && ne_data.data == 2,
		"Rect {75,25,10,10} in NE",
	)
	testing.expect(
		t,
		sw_data.rect == Rectangle{25, 75, 10, 10} && sw_data.data == 3,
		"Rect {25,75,10,10} in SW",
	)
	testing.expect(
		t,
		se_data.rect == Rectangle{75, 75, 10, 10} && se_data.data == 4,
		"Rect {75,75,10,10} in SE",
	)

	// intersects quadrant boundary line, stays in root
	testing.expect(
		t,
		root_data.rect == Rectangle{45, 45, 10, 10} && root_data.data == 5,
		"Rect {45,45,10,10} in root",
	)
}

@(test)
test_query_rectangle :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{10, 10, 10, 10}, 1)
	insert(&tree, Rectangle{90, 90, 10, 10}, 2)
	insert(&tree, Rectangle{50, 50, 10, 10}, 3)

	found := query_rectangle(&tree, Rectangle{0, 0, 60, 60})
	testing.expect(t, len(found) == 2, "Should find 2 points in range")
}

@(test)
test_out_of_bounds :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	testing.expect(
		t,
		!insert(&tree, Rectangle{-10, 50, 10, 10}, 1),
		"Should reject out of bounds point",
	)
	testing.expect(
		t,
		!insert(&tree, Rectangle{110, 50, 10, 10}, 2),
		"Should reject out of bounds point",
	)
}

@(test)
test_query_circle :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{10, 10, 10, 10}, 1)
	insert(&tree, Rectangle{90, 90, 10, 10}, 2)
	insert(&tree, Rectangle{50, 50, 10, 10}, 3)
	insert(&tree, Rectangle{30, 30, 10, 10}, 4)

	found := query_circle(&tree, 50, 50, 30)
	testing.expect(t, len(found) == 2, "Should find 2 rectangles in circle")

	found = query_circle(&tree, 20, 20, 15)
	testing.expect(t, len(found) == 2, "Should find 2 rectangles near corner")

	found = query_circle(&tree, 95, 95, 10)
	testing.expect(t, len(found) == 1, "Should find 1 rectangle in small circle")

	found = query_circle(&tree, 10, 95, 10)
	testing.expect(t, len(found) == 0, "Should find 0 rectangles")
}

@(test)
test_query_circle_empty :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	found := query_circle(&tree, 50, 50, 20)
	testing.expect(t, len(found) == 0, "Should find no rectangles in empty tree")
}

@(test)
test_query_point :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{10, 10, 20, 20}, 1)
	insert(&tree, Rectangle{50, 50, 30, 30}, 2)
	insert(&tree, Rectangle{80, 80, 15, 15}, 3)

	found := query_point(&tree, 15, 15)
	testing.expect(t, len(found) == 1, "Should find 1 rectangle containing point")
	testing.expect(t, found[0].data == 1, "Should find correct rectangle")

	found = query_point(&tree, 60, 60)
	testing.expect(t, len(found) == 1, "Should find rectangle in middle")
	testing.expect(t, found[0].data == 2, "Should find correct rectangle")

	found = query_point(&tree, 5, 5)
	testing.expect(t, len(found) == 0, "Should find no rectangles outside all")
}

@(test)
test_query_point_overlapping :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 50, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{10, 10, 30, 30}, 1)
	insert(&tree, Rectangle{20, 20, 30, 30}, 2)
	insert(&tree, Rectangle{30, 30, 30, 30}, 3)

	found := query_point(&tree, 35, 35)
	testing.expect(t, len(found) == 3, "Should find all overlapping rectangles")
}
