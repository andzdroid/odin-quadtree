package quadtree

import "core:math"

SUBDIVISION_THRESHOLD :: 4

Rectangle :: struct {
	x, y, width, height: f32,
}

Entry :: struct($T: typeid) {
	rect: Rectangle,
	data: T,
}

Node :: struct($EntriesPerNode: int) {
	bounds:   Rectangle,
	entries:  [EntriesPerNode]int, // entry indices
	size:     int,
	level:    int,
	divided:  bool,
	children: [4]int, // child node indices
}

Quadtree :: struct(
	$MaxNodes: int,
	$MaxEntries: int,
	$EntriesPerNode: int,
	$MaxResults: int,
	$T: typeid,
)
{
	nodes:       [MaxNodes]Node(EntriesPerNode),
	entries:     [MaxEntries]Entry(T),
	node_count:  int,
	entry_count: int,
	results:     [MaxResults]Entry(T),
}

Quadrant :: enum {
	None,
	NW,
	NE,
	SW,
	SE,
}

init :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	bounds: Rectangle,
) {
	assert(bounds.width > 0 && bounds.height > 0, "bounds must have positive dimensions")

	qt.nodes[0] = {
		bounds = bounds,
	}
	qt.node_count = 1
}

contains :: proc(rect: Rectangle, rect2: Rectangle) -> bool {
	return(
		rect2.x >= rect.x &&
		rect2.x + rect2.width <= rect.x + rect.width &&
		rect2.y >= rect.y &&
		rect2.y + rect2.height <= rect.y + rect.height \
	)
}

intersects :: proc(rect1, rect2: Rectangle) -> bool {
	return(
		!(rect2.x > rect1.x + rect1.width ||
			rect2.x + rect2.width < rect1.x ||
			rect2.y > rect1.y + rect1.height ||
			rect2.y + rect2.height < rect1.y) \
	)
}

subdivide :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	node_idx: int,
) -> bool {
	assert(node_idx >= 0, "invalid node index")
	assert(!qt.nodes[node_idx].divided, "node already subdivided")
	if qt.node_count + 4 > int(MaxNodes) {
		return false
	}

	node := &qt.nodes[node_idx]
	half_width := node.bounds.width / 2
	half_height := node.bounds.height / 2
	x := node.bounds.x
	y := node.bounds.y

	// create 4 child nodes
	for i in 0 ..< 4 {
		child_idx := qt.node_count
		qt.node_count += 1
		node.children[i] = child_idx

		bounds: Rectangle
		switch i {
		case 0:
			bounds = {x, y, half_width, half_height}
		case 1:
			bounds = {x + half_width, y, half_width, half_height}
		case 2:
			bounds = {x, y + half_height, half_width, half_height}
		case 3:
			bounds = {x + half_width, y + half_height, half_width, half_height}
		}

		qt.nodes[child_idx] = {
			bounds = bounds,
			level  = node.level + 1,
		}
	}

	node.divided = true

	// try to move entries into children
	if node.size > 0 {
		for i := node.size - 1; i >= 0; i -= 1 {
			entry_index := node.entries[i]
			entry := qt.entries[entry_index]
			quadrant := get_quadrant(node, entry.rect)
			if quadrant == .None {
				continue
			}

			index := get_quadrant_index(quadrant)
			child_node := &qt.nodes[node.children[index]]
			child_node.entries[child_node.size] = entry_index
			child_node.size += 1

			node.entries[i] = node.entries[node.size - 1]
			node.size -= 1
		}
	}

	return true
}

get_quadrant :: proc(node: ^Node($EntriesPerNode), rect: Rectangle) -> Quadrant {
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

get_quadrant_index :: proc(quadrant: Quadrant) -> int {
	switch quadrant {
	case .NW:
		return 0
	case .NE:
		return 1
	case .SW:
		return 2
	case .SE:
		return 3
	case .None:
		return -1
	}
	return -1
}

insert :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	rect: Rectangle,
	data: T,
) -> bool {
	return insert_node(qt, 0, rect, data)
}

insert_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	node_idx: int,
	rect: Rectangle,
	data: T,
) -> bool {
	node := &qt.nodes[node_idx]
	if !contains(node.bounds, rect) {
		return false
	}

	if qt.entry_count >= int(MaxEntries) {
		return false
	}

	// not divided yet, insert into current node
	if node.size < SUBDIVISION_THRESHOLD && !node.divided {
		if node.size >= int(EntriesPerNode) {
			return false
		}

		node.entries[node.size] = qt.entry_count
		qt.entries[qt.entry_count] = {rect, data}
		qt.entry_count += 1
		node.size += 1
		return true
	}

	if !node.divided {
		subdivide(qt, node_idx) or_return
	}

	quadrant := get_quadrant(node, rect)
	// insert into child node
	if quadrant != .None {
		index := get_quadrant_index(quadrant)
		assert(node.divided, "node was not subdivided")
		return insert_node(qt, node.children[index], rect, data)
	}


	// insert into current node
	if node.size >= int(EntriesPerNode) {
		return false
	}

	node.entries[node.size] = qt.entry_count
	qt.entries[qt.entry_count] = {rect, data}
	qt.entry_count += 1
	node.size += 1
	return true
}

query_rectangle :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	rect: Rectangle,
) -> []Entry(T) {
	count := query_rectangle_node(qt, 0, rect, 0)
	return qt.results[:count]
}

query_rectangle_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
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
	for i in 0 ..< node.size {
		if result_count >= MaxResults {
			break
		}
		entry_index := node.entries[i]
		entry := qt.entries[entry_index]
		intersects(rect, entry.rect) or_continue
		qt.results[result_count] = entry
		result_count += 1
	}

	if node.divided {
		for child_idx in node.children {
			result_count = query_rectangle_node(qt, child_idx, rect, result_count)
		}
	}

	return result_count
}

circle_intersects_rectangle :: proc(center_x, center_y, radius: f32, rect: Rectangle) -> bool {
	closest_x := math.clamp(center_x, rect.x, rect.x + rect.width)
	closest_y := math.clamp(center_y, rect.y, rect.y + rect.height)

	distance_x := center_x - closest_x
	distance_y := center_y - closest_y

	return distance_x * distance_x + distance_y * distance_y <= radius * radius
}

query_circle :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	center_x, center_y, radius: f32,
) -> []Entry(T) {
	assert(radius >= 0, "radius must be non-negative")
	count := query_circle_node(qt, 0, center_x, center_y, radius, 0)
	return qt.results[:count]
}

query_circle_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	node_idx: int,
	center_x, center_y, radius: f32,
	count: int,
) -> int {
	if count >= MaxResults {
		return count
	}

	node := &qt.nodes[node_idx]
	if !circle_intersects_rectangle(center_x, center_y, radius, node.bounds) {
		return count
	}

	result_count := count
	for i in 0 ..< node.size {
		if result_count >= MaxResults {
			break
		}
		entry_index := node.entries[i]
		entry := qt.entries[entry_index]
		circle_intersects_rectangle(center_x, center_y, radius, entry.rect) or_continue
		qt.results[result_count] = entry
		result_count += 1
	}

	if node.divided {
		for child_idx in node.children {
			result_count = query_circle_node(
				qt,
				child_idx,
				center_x,
				center_y,
				radius,
				result_count,
			)
		}
	}

	return result_count
}

point_in_rectangle :: proc(x, y: f32, rect: Rectangle) -> bool {
	return x >= rect.x && x <= rect.x + rect.width && y >= rect.y && y <= rect.y + rect.height
}

query_point :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	x, y: f32,
) -> []Entry(T) {
	count := query_point_node(qt, 0, x, y, 0)
	return qt.results[:count]
}

query_point_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	node_idx: int,
	x, y: f32,
	count: int,
) -> int {
	if count >= MaxResults {
		return count
	}

	node := &qt.nodes[node_idx]
	if !point_in_rectangle(x, y, node.bounds) {
		return count
	}

	result_count := count
	for i in 0 ..< node.size {
		if result_count >= MaxResults {
			break
		}
		entry_index := node.entries[i]
		entry := qt.entries[entry_index]
		point_in_rectangle(x, y, entry.rect) or_continue
		qt.results[result_count] = entry
		result_count += 1
	}

	if node.divided {
		for child_idx in node.children {
			result_count = query_point_node(qt, child_idx, x, y, result_count)
		}
	}

	return result_count
}
