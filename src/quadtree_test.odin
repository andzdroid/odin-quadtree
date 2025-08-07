package quadtree

import "core:log"
import "core:testing"

@(test)
test_quadtree_creation :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)
	testing.expect(t, tree.nodes[0].bounds == bounds, "Root bounds should match")
}

@(test)
test_point_insertion :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	p1 := Rectangle{25, 25, 10, 10}
	p2 := Rectangle{75, 75, 10, 10}

	idx1, ok := insert(&tree, p1, 1)
	testing.expect(t, ok, "Should insert point within bounds")
	testing.expect(t, idx1 == 1, "Should return index 1")
	idx2, ok2 := insert(&tree, p2, 2)
	testing.expect(t, ok2, "Should insert second point")
	testing.expect(t, idx2 == 2, "Should return index 2")
	testing.expect(t, tree.nodes[0].size == 2, "Root should have 2 points")
}

@(test)
test_subdivision :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{25, 25, 10, 10}, 1)
	insert(&tree, Rectangle{75, 25, 10, 10}, 2)
	insert(&tree, Rectangle{25, 75, 10, 10}, 3)
	insert(&tree, Rectangle{75, 75, 10, 10}, 4)
	insert(&tree, Rectangle{45, 45, 10, 10}, 5)

	testing.expect(t, tree.nodes[0].children != 0, "Should subdivide")
	testing.expect(t, tree.nodes[0].size == 1, "Root should have 1 entry after subdivision")

	nw := tree.nodes[0].children
	ne := tree.nodes[0].children + 1
	sw := tree.nodes[0].children + 2
	se := tree.nodes[0].children + 3

	testing.expect(t, tree.nodes[nw].size == 1, "NW should have 1 entry")
	testing.expect(t, tree.nodes[ne].size == 1, "NE should have 1 entry")
	testing.expect(t, tree.nodes[sw].size == 1, "SW should have 1 entry")
	testing.expect(t, tree.nodes[se].size == 1, "SE should have 1 entry")

	nw_node := &tree.nodes[nw]
	ne_node := &tree.nodes[ne]
	sw_node := &tree.nodes[sw]
	se_node := &tree.nodes[se]
	root_node := &tree.nodes[0]

	nw_data := tree.entries[nw_node.entries]
	ne_data := tree.entries[ne_node.entries]
	sw_data := tree.entries[sw_node.entries]
	se_data := tree.entries[se_node.entries]
	root_data := tree.entries[root_node.entries]

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
	tree: Quadtree(100, 100, 10, int)
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
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, ok1 := insert(&tree, Rectangle{-10, 50, 10, 10}, 1)
	testing.expect(t, !ok1, "Should reject out of bounds point")
	idx2, ok2 := insert(&tree, Rectangle{110, 50, 10, 10}, 2)
	testing.expect(t, !ok2, "Should reject out of bounds point")
}

@(test)
test_query_circle :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
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
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	found := query_circle(&tree, 50, 50, 20)
	testing.expect(t, len(found) == 0, "Should find no rectangles in empty tree")
}

@(test)
test_query_point :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
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
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{10, 10, 30, 30}, 1)
	insert(&tree, Rectangle{20, 20, 30, 30}, 2)
	insert(&tree, Rectangle{30, 30, 30, 30}, 3)

	found := query_point(&tree, 35, 35)
	testing.expect(t, len(found) == 3, "Should find all overlapping rectangles")
}

@(test)
test_remove_basic :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx, ok := insert(&tree, Rectangle{25, 25, 10, 10}, 1)
	testing.expect(t, ok, "Should insert entry")
	testing.expect(t, tree.nodes[0].size == 1, "Should have 1 entry")

	removed := remove(&tree, idx)
	testing.expect(t, removed, "Should remove entry")
	testing.expect(t, tree.nodes[0].size == 0, "Should have 0 entries after removal")
	testing.expect(t, tree.entry_count == 1, "Entry count should be 1")
	testing.expect(t, tree.next_free == idx, "Index should be next free entry")
}

@(test)
test_remove_invalid_index :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{25, 25, 10, 10}, 1)

	removed := remove(&tree, 999)
	testing.expect(t, !removed, "Should not remove invalid index")
	testing.expect(t, tree.nodes[0].size == 1, "Should still have 1 entry")
}

@(test)
test_remove_from_subdivided :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, _ := insert(&tree, Rectangle{25, 25, 10, 10}, 1)
	idx2, _ := insert(&tree, Rectangle{75, 25, 10, 10}, 2)
	idx3, _ := insert(&tree, Rectangle{25, 75, 10, 10}, 3)
	idx4, _ := insert(&tree, Rectangle{75, 75, 10, 10}, 4)
	idx5, _ := insert(&tree, Rectangle{45, 45, 10, 10}, 5)

	testing.expect(t, tree.nodes[0].children != 0, "Should be subdivided")

	removed := remove(&tree, idx2)
	testing.expect(t, removed, "Should remove from NE quadrant")

	ne_idx := tree.nodes[0].children + 1
	testing.expect(t, tree.nodes[ne_idx].size == 0, "NE should be empty")

	found := query_rectangle(&tree, Rectangle{70, 20, 20, 20})
	testing.expect(t, len(found) == 0, "Should not find removed entry")

	found = query_rectangle(&tree, Rectangle{20, 20, 20, 20})
	testing.expect(t, len(found) == 1, "Should still find NW entry")
}

@(test)
test_remove_from_root_after_subdivision :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, _ := insert(&tree, Rectangle{25, 25, 10, 10}, 1)
	idx2, _ := insert(&tree, Rectangle{75, 25, 10, 10}, 2)
	idx3, _ := insert(&tree, Rectangle{25, 75, 10, 10}, 3)
	idx4, _ := insert(&tree, Rectangle{75, 75, 10, 10}, 4)
	idx5, _ := insert(&tree, Rectangle{45, 45, 10, 10}, 5)

	testing.expect(t, tree.nodes[0].size == 1, "Root should have 1 entry")

	removed := remove(&tree, idx5)
	testing.expect(t, removed, "Should remove from root")
	testing.expect(t, tree.nodes[0].size == 0, "Root should be empty")

	found := query_rectangle(&tree, Rectangle{40, 40, 20, 20})
	testing.expect(t, len(found) == 0, "Should not find removed entry")
}

@(test)
test_remove_multiple_entries :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, _ := insert(&tree, Rectangle{10, 10, 10, 10}, 1)
	idx2, _ := insert(&tree, Rectangle{30, 30, 10, 10}, 2)
	idx3, _ := insert(&tree, Rectangle{50, 50, 10, 10}, 3)

	testing.expect(t, tree.nodes[0].size == 3, "Should have 3 entries")

	remove(&tree, idx2)
	testing.expect(t, tree.nodes[0].size == 2, "Should have 2 entries")

	remove(&tree, idx1)
	testing.expect(t, tree.nodes[0].size == 1, "Should have 1 entry")

	remove(&tree, idx3)
	testing.expect(t, tree.nodes[0].size == 0, "Should have 0 entries")

	found := query_rectangle(&tree, Rectangle{0, 0, 100, 100})
	log.infof("found: %v", found)
	testing.expect(t, len(found) == 0, "Should find no entries")
}

@(test)
test_remove_and_reinsert :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, _ := insert(&tree, Rectangle{25, 25, 10, 10}, 1)
	remove(&tree, idx1)

	idx2, ok := insert(&tree, Rectangle{30, 30, 10, 10}, 2)
	testing.expect(t, ok, "Should reinsert after removal")
	testing.expect(t, idx2 == idx1, "Should reuse freed index")
	testing.expect(t, tree.next_free == 0, "No free entries")

	found := query_rectangle(&tree, Rectangle{25, 25, 20, 20})
	testing.expect(t, len(found) == 1, "Should find reinserted entry")
	testing.expect(t, found[0].data == 2, "Should have correct data")
}

@(test)
test_update_basic :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx, ok := insert(&tree, Rectangle{25, 25, 10, 10}, 1)
	testing.expect(t, ok, "Should insert entry")

	new_idx, updated := update(&tree, idx, Rectangle{75, 75, 10, 10}, 2)
	testing.expect(t, updated, "Should update entry")
	testing.expect(t, new_idx == idx, "Should reuse same index")

	found := query_rectangle(&tree, Rectangle{20, 20, 20, 20})
	testing.expect(t, len(found) == 0, "Should not find old entry")

	found = query_rectangle(&tree, Rectangle{70, 70, 20, 20})
	testing.expect(t, len(found) == 1, "Should find updated entry")
	testing.expect(t, found[0].data == 2, "Should have updated data")
}

@(test)
test_update_invalid_index :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{25, 25, 10, 10}, 1)

	new_idx, updated := update(&tree, 999, Rectangle{75, 75, 10, 10}, 2)
	testing.expect(t, !updated, "Should not update invalid index")
	testing.expect(t, new_idx == 0, "Should return 0 for invalid update")
	testing.expect(t, tree.nodes[0].size == 1, "Should still have original entry")
}

@(test)
test_update_out_of_bounds :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx, _ := insert(&tree, Rectangle{25, 25, 10, 10}, 1)

	new_idx, updated := update(&tree, idx, Rectangle{-10, 50, 10, 10}, 2)
	testing.expect(t, !updated, "Should not update to out of bounds")
	testing.expect(t, new_idx == 0, "Should return 0 for failed update")
	testing.expect(t, tree.nodes[0].size == 0, "Entry should be removed even if reinsert fails")
}

@(test)
test_update_subdivided_to_different_quadrant :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, _ := insert(&tree, Rectangle{25, 25, 10, 10}, 1) // NW
	idx2, _ := insert(&tree, Rectangle{75, 25, 10, 10}, 2) // NE
	idx3, _ := insert(&tree, Rectangle{25, 75, 10, 10}, 3) // SW
	idx4, _ := insert(&tree, Rectangle{75, 75, 10, 10}, 4) // SE
	idx5, _ := insert(&tree, Rectangle{45, 45, 10, 10}, 5) // middle

	testing.expect(t, tree.nodes[0].children != 0, "Should be subdivided")

	new_idx, updated := update(&tree, idx1, Rectangle{80, 80, 10, 10}, 10)
	testing.expect(t, updated, "Should update from NW to SE")

	nw_idx := tree.nodes[0].children
	se_idx := tree.nodes[0].children + 3
	testing.expect(t, tree.nodes[nw_idx].size == 0, "NW should be empty")
	testing.expect(t, tree.nodes[se_idx].size == 2, "SE should have 2 entries")

	found := query_rectangle(&tree, Rectangle{20, 20, 20, 20})
	testing.expect(t, len(found) == 0, "Should not find old NW entry")

	found = query_rectangle(&tree, Rectangle{75, 75, 20, 20})
	testing.expect(t, len(found) == 2, "Should find both SE entries")
}

@(test)
test_update_same_position_different_data :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx, _ := insert(&tree, Rectangle{25, 25, 10, 10}, 1)

	new_idx, updated := update(&tree, idx, Rectangle{25, 25, 10, 10}, 999)
	testing.expect(t, updated, "Should update data at same position")
	testing.expect(t, new_idx == idx, "Should reuse same index")

	found := query_rectangle(&tree, Rectangle{20, 20, 20, 20})
	testing.expect(t, len(found) == 1, "Should find entry at same position")
	testing.expect(t, found[0].data == 999, "Should have updated data")
}

@(test)
test_update_multiple_sequential :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx, _ := insert(&tree, Rectangle{25, 25, 10, 10}, 1)

	idx2, ok := update(&tree, idx, Rectangle{50, 50, 10, 10}, 2)
	testing.expect(t, ok, "First update should succeed")

	idx3, ok2 := update(&tree, idx2, Rectangle{75, 75, 10, 10}, 3)
	testing.expect(t, ok2, "Second update should succeed")

	found := query_rectangle(&tree, Rectangle{70, 70, 20, 20})
	testing.expect(t, len(found) == 1, "Should find final position")
	testing.expect(t, found[0].data == 3, "Should have final data")

	found = query_rectangle(&tree, Rectangle{20, 20, 60, 60})
	testing.expect(t, len(found) == 1, "Should only find one entry total")
}

@(test)
test_node_entry_list_integrity :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	insert(&tree, Rectangle{10, 10, 10, 10}, 1)
	insert(&tree, Rectangle{30, 30, 10, 10}, 2)
	insert(&tree, Rectangle{50, 50, 10, 10}, 3)

	for node_idx in 0 ..< tree.node_count {
		node := &tree.nodes[node_idx]
		if node.size == 0 {
			testing.expect(t, node.entries == 0, "Empty node should have entries = 0")
			continue
		}

		current := node.entries
		prev_idx := 0
		count := 0
		for current != 0 {
			entry := &tree.entries[current]

			// First entry has prev = 0
			if prev_idx == 0 {
				testing.expect(t, entry.prev == 0, "First entry should have prev = 0")
			} else {
				testing.expect(t, entry.prev == prev_idx, "Prev should point to previous entry")
			}

			testing.expect(t, entry.node == node_idx, "Entry.node should match actual node")

			count += 1
			testing.expect(t, count <= node.size, "No circular references in entry list")

			prev_idx = current
			current = entry.next
		}

		// Node size should match actual count
		testing.expect(t, count == node.size, "Node size should match actual entry count")
	}
}

@(test)
test_free_list_integrity :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, _ := insert(&tree, Rectangle{10, 10, 10, 10}, 1)
	idx2, _ := insert(&tree, Rectangle{30, 30, 10, 10}, 2)
	idx3, _ := insert(&tree, Rectangle{50, 50, 10, 10}, 3)
	remove(&tree, idx2)
	remove(&tree, idx1)

	if tree.next_free != 0 {
		// next_free points to valid free entry
		testing.expect(
			t,
			tree.next_free > 0 && tree.next_free <= tree.entry_count,
			"next_free should point to valid entry index",
		)

		current := tree.next_free
		count := 0
		for current != 0 {
			entry := &tree.entries[current]
			testing.expect(t, entry.node == 0, "Free entry should have node = 0")
			testing.expect(t, entry.prev == 0, "Free entry should have prev = 0")

			count += 1
			testing.expect(t, count <= tree.entry_count, "Free list should not have cycles")

			current = entry.next
		}
	}
}

@(test)
test_subdivision_pointer_integrity :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, _ := insert(&tree, Rectangle{25, 25, 10, 10}, 1) // NW
	idx2, _ := insert(&tree, Rectangle{75, 25, 10, 10}, 2) // NE
	idx3, _ := insert(&tree, Rectangle{25, 75, 10, 10}, 3) // SW
	idx4, _ := insert(&tree, Rectangle{75, 75, 10, 10}, 4) // SE
	idx5, _ := insert(&tree, Rectangle{45, 45, 10, 10}, 5) // Center (stays in root)

	testing.expect(t, tree.nodes[0].children != 0, "Root should be subdivided")

	// After subdivision: no entry appears in multiple node lists
	entry_node_map := make(map[int]int) // entry_idx -> node_idx
	defer delete(entry_node_map)

	for node_idx in 0 ..< tree.node_count {
		node := &tree.nodes[node_idx]
		current := node.entries

		for current != 0 {
			if existing_node, exists := entry_node_map[current]; exists {
				testing.expect(t, false, "Entry appears in multiple nodes")
			}
			entry_node_map[current] = node_idx

			entry := &tree.entries[current]
			testing.expect(t, entry.node == node_idx, "Entry.node should match containing node")
			current = entry.next
		}
	}

	active_entries := len(entry_node_map)
	testing.expect(t, active_entries == 5, "All entries should be here")
}

@(test)
test_remove_and_free_list_transition :: proc(t: ^testing.T) {
	tree: Quadtree(100, 100, 10, int)
	bounds := Rectangle{0, 0, 100, 100}
	init(&tree, bounds)

	idx1, _ := insert(&tree, Rectangle{10, 10, 10, 10}, 1)
	idx2, _ := insert(&tree, Rectangle{30, 30, 10, 10}, 2)
	idx3, _ := insert(&tree, Rectangle{50, 50, 10, 10}, 3)

	old_next_free := tree.next_free

	// Remove middle entry
	removed := remove(&tree, idx2)
	testing.expect(t, removed, "Should successfully remove entry")

	root := &tree.nodes[0]
	current := root.entries
	found_removed_in_active := false
	for current != 0 {
		if current == idx2 {
			found_removed_in_active = true
			break
		}
		current = tree.entries[current].next
	}
	testing.expect(t, !found_removed_in_active, "Removed entry should not be in active node list")

	testing.expect(t, tree.next_free == idx2, "Removed entry should become next_free")
	removed_entry := &tree.entries[idx2]
	testing.expect(
		t,
		removed_entry.next == old_next_free,
		"Removed entry should link to old next_free",
	)
	testing.expect(t, removed_entry.prev == 0, "Removed entry should have prev = 0 in free list")
	testing.expect(t, removed_entry.node == 0, "Removed entry should have node = 0")

	idx4, ok := insert(&tree, Rectangle{70, 70, 10, 10}, 4)
	testing.expect(t, ok, "Should be able to reuse freed entry")
	testing.expect(t, idx4 == idx2, "Should reuse the freed entry index")
	testing.expect(t, tree.next_free == old_next_free, "next_free should be updated to old value")

	reused_entry := &tree.entries[idx4]
	testing.expect(t, reused_entry.data == 4, "Reused entry should have new data")
	testing.expect(t, reused_entry.node == 0, "Reused entry should be in root node")
	testing.expect(t, reused_entry.prev == 0, "Reused entry should be first in node list")
}
