package quadtree

import "core:log"
import "core:math"

SUBDIVISION_THRESHOLD :: 4

Rectangle :: struct {
	x, y, width, height: f32,
}

Entry :: struct($T: typeid) {
	rect: Rectangle,
	data: T,
	node: int,
	next: int,
	prev: int,
}

Node :: struct {
	bounds:   Rectangle,
	entries:  int, // index of first entry
	size:     int,
	children: int, // start index of child node indices, child nodes are contiguous
}

Quadtree :: struct($MaxNodes: int, $MaxEntries: int, $MaxResults: int, $T: typeid) {
	nodes:       [MaxNodes]Node,
	entries:     [MaxEntries]Entry(T),
	node_count:  int,
	entry_count: int,
	next_free:   int,
	results:     [MaxResults]Entry(T),
}

Quadrant :: enum {
	None = -1,
	NW   = 0,
	NE   = 1,
	SW   = 2,
	SE   = 3,
}

init :: proc(qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T), bounds: Rectangle) {
	assert(bounds.width > 0 && bounds.height > 0, "bounds must have positive dimensions")
	qt.nodes[0] = {
		bounds = bounds,
	}
	qt.node_count = 1
}

subdivide :: proc(qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T), node_idx: int) -> bool {
	assert(node_idx >= 0, "invalid node index")
	assert(qt.nodes[node_idx].children == 0, "node already subdivided")
	if qt.node_count + 4 > int(MaxNodes) {
		log.infof("Quadtree nodes are full: %v / %v", qt.node_count, int(MaxNodes))
		return false
	}

	node := &qt.nodes[node_idx]

	// create 4 child nodes
	node.children = qt.node_count
	qt.node_count += 4
	for i in 0 ..< 4 {
		child_idx := node.children + i
		qt.nodes[child_idx] = {
			bounds = get_quadrant_bounds(node.bounds, Quadrant(i)),
		}
	}

	// try to move entries into children
	if node.size > 0 {
		current_index := node.entries
		for current_index != 0 {
			entry := &qt.entries[current_index]
			next_index := entry.next
			prev_index := entry.prev

			quadrant := get_quadrant(node, entry.rect)
			if quadrant == .None {
				current_index = next_index
				continue
			}

			index := int(quadrant)
			child_node_idx := node.children + index
			child_node := &qt.nodes[child_node_idx]

			// insert entry into child node
			entry.next = child_node.entries
			entry.prev = 0
			entry.node = child_node_idx
			child_node.entries = current_index
			child_node.size += 1
			if entry.next != 0 {
				qt.entries[entry.next].prev = current_index
			}

			// remove entry from current node, update previous node's entries
			if node.entries == current_index {
				node.entries = next_index
			}
			if prev_index != 0 {
				qt.entries[prev_index].next = next_index
			}
			if next_index != 0 {
				qt.entries[next_index].prev = prev_index
			}

			node.size -= 1

			current_index = next_index
		}
	}

	return true
}

get_quadrant :: proc(node: ^Node, rect: Rectangle) -> Quadrant {
	half_width := node.bounds.width / 2
	half_height := node.bounds.height / 2
	mid_x := node.bounds.x + half_width
	mid_y := node.bounds.y + half_height

	top := rect.y + rect.height < mid_y
	bottom := rect.y >= mid_y
	left := rect.x + rect.width < mid_x
	right := rect.x >= mid_x

	if top && right do return .NE
	if top && left do return .NW
	if bottom && left do return .SW
	if bottom && right do return .SE
	return .None
}

get_quadrant_bounds :: proc(rect: Rectangle, quadrant: Quadrant) -> Rectangle {
	half_width := rect.width / 2
	half_height := rect.height / 2
	x := rect.x
	y := rect.y

	switch quadrant {
	case .NW:
		return {x, y, half_width, half_height}
	case .NE:
		return {x + half_width, y, half_width, half_height}
	case .SW:
		return {x, y + half_height, half_width, half_height}
	case .SE:
		return {x + half_width, y + half_height, half_width, half_height}
	case .None:
		return {}
	}
	return {}
}

get_next_index :: proc(qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T)) -> int {
	if qt.next_free != 0 {
		index := qt.next_free
		qt.next_free = qt.entries[index].next
		return index
	}

	index := qt.entry_count + 1
	qt.entry_count += 1
	return index
}

insert :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	rect: Rectangle,
	data: T,
) -> (
	int,
	bool,
) {
	return insert_node(qt, 0, rect, data)
}

insert_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	rect: Rectangle,
	data: T,
) -> (
	int,
	bool,
) {
	node := &qt.nodes[node_idx]
	if !contains(node.bounds, rect) {
		return 0, false
	}

	if qt.entry_count >= int(MaxEntries) && qt.next_free == 0 {
		// log.infof("Quadtree entries are full: %v / %v", qt.entry_count, int(MaxEntries))
		return 0, false
	}

	if node.size < SUBDIVISION_THRESHOLD && node.children == 0 {
		return insert_entry(qt, node_idx, rect, data)
	}

	reached_node_limit := qt.node_count + 4 > int(MaxNodes)
	if node.children == 0 && !reached_node_limit {
		if !subdivide(qt, node_idx) {
			return 0, false
		}
	}

	quadrant := get_quadrant(node, rect)
	// insert into child node
	if quadrant != .None && node.children != 0 {
		return insert_node(qt, node.children + int(quadrant), rect, data)
	}

	// insert into current node
	return insert_entry(qt, node_idx, rect, data)
}

insert_entry :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	rect: Rectangle,
	data: T,
) -> (
	int,
	bool,
) {
	node := &qt.nodes[node_idx]
	index := get_next_index(qt)
	qt.entries[index] = {
		rect = rect,
		data = data,
		node = node_idx,
		next = node.entries,
		prev = 0,
	}
	if node.entries != 0 {
		qt.entries[node.entries].prev = index
	}
	node.entries = index
	node.size += 1
	return index, true
}

remove :: proc(qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T), index: int) -> bool {
	if index < 0 || index > qt.entry_count {
		return false
	}

	entry := &qt.entries[index]
	node := &qt.nodes[entry.node]

	if node.entries == index {
		node.entries = entry.next
	}
	if entry.prev != 0 {
		qt.entries[entry.prev].next = entry.next
	}
	if entry.next != 0 {
		qt.entries[entry.next].prev = entry.prev
	}

	// move to free list
	node.size -= 1
	entry.next = qt.next_free
	entry.prev = 0
	entry.node = 0
	if entry.next != 0 {
		qt.entries[entry.next].prev = index
	}
	qt.next_free = index
	return true
}

update :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	index: int,
	rect: Rectangle,
	data: T,
) -> (
	int,
	bool,
) {
	if !remove(qt, index) {
		return 0, false
	}
	return insert(qt, rect, data)
}

query_rectangle :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	rect: Rectangle,
) -> []Entry(T) {
	count := query_rectangle_node(qt, 0, rect, 0)
	return qt.results[:count]
}

query_rectangle_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	rect: Rectangle,
	count: int,
) -> int {
	if count >= MaxResults {
		return count
	}

	node := &qt.nodes[node_idx]
	if !intersects(node.bounds, rect) {
		return count
	}

	result_count := count
	current_index := node.entries
	for current_index != 0 {
		if result_count >= MaxResults {
			break
		}

		entry := qt.entries[current_index]
		if !intersects(rect, entry.rect) {
			current_index = entry.next
			continue
		}

		qt.results[result_count] = entry
		result_count += 1
		current_index = entry.next
	}

	if node.children != 0 {
		for child_idx in 0 ..< 4 {
			result_count = query_rectangle_node(qt, node.children + child_idx, rect, result_count)
		}
	}

	return result_count
}

query_circle :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	center_x, center_y, radius: f32,
) -> []Entry(T) {
	assert(radius >= 0, "radius must be non-negative")
	count := query_circle_node(qt, 0, center_x, center_y, radius, 0)
	return qt.results[:count]
}

query_circle_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	center_x, center_y, radius: f32,
	count: int,
) -> int {
	if count >= MaxResults {
		return count
	}

	node := &qt.nodes[node_idx]
	if !intersects(node.bounds, center_x, center_y, radius) {
		return count
	}

	result_count := count
	current_index := node.entries
	for current_index != 0 {
		if result_count >= MaxResults {
			break
		}

		entry := qt.entries[current_index]
		if !intersects(entry.rect, center_x, center_y, radius) {
			current_index = entry.next
			continue
		}

		qt.results[result_count] = entry
		result_count += 1
		current_index = entry.next
	}

	if node.children != 0 {
		for child_idx in 0 ..< 4 {
			result_count = query_circle_node(
				qt,
				node.children + child_idx,
				center_x,
				center_y,
				radius,
				result_count,
			)
		}
	}

	return result_count
}

query_point :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	x, y: f32,
) -> []Entry(T) {
	count := query_point_node(qt, 0, x, y, 0)
	return qt.results[:count]
}

query_point_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	x, y: f32,
	count: int,
) -> int {
	if count >= MaxResults {
		return count
	}

	node := &qt.nodes[node_idx]
	if !contains(node.bounds, x, y) {
		return count
	}

	result_count := count
	current_index := node.entries
	for current_index != 0 {
		if result_count >= MaxResults {
			break
		}

		entry := qt.entries[current_index]
		if !contains(entry.rect, x, y) {
			current_index = entry.next
			continue
		}

		qt.results[result_count] = entry
		result_count += 1
		current_index = entry.next
	}

	if node.children != 0 {
		for child_idx in 0 ..< 4 {
			result_count = query_point_node(qt, node.children + child_idx, x, y, result_count)
		}
	}

	return result_count
}

contains :: proc {
	contains_rectangle,
	contains_point,
}

contains_rectangle :: proc(rect: Rectangle, rect2: Rectangle) -> bool {
	return(
		rect2.x >= rect.x &&
		rect2.x + rect2.width <= rect.x + rect.width &&
		rect2.y >= rect.y &&
		rect2.y + rect2.height <= rect.y + rect.height \
	)
}

contains_point :: proc(rect: Rectangle, x, y: f32) -> bool {
	return x >= rect.x && x <= rect.x + rect.width && y >= rect.y && y <= rect.y + rect.height
}

intersects :: proc {
	intersects_rectangle,
	intersects_circle,
}

intersects_rectangle :: proc(rect1, rect2: Rectangle) -> bool {
	return(
		!(rect2.x > rect1.x + rect1.width ||
			rect2.x + rect2.width < rect1.x ||
			rect2.y > rect1.y + rect1.height ||
			rect2.y + rect2.height < rect1.y) \
	)
}

intersects_circle :: proc(rect: Rectangle, center_x, center_y, radius: f32) -> bool {
	closest_x := math.clamp(center_x, rect.x, rect.x + rect.width)
	closest_y := math.clamp(center_y, rect.y, rect.y + rect.height)
	distance_x := center_x - closest_x
	distance_y := center_y - closest_y
	return distance_x * distance_x + distance_y * distance_y <= radius * radius
}
