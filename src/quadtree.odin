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
}

Node :: struct($EntriesPerNode: int) {
	bounds:   Rectangle,
	entries:  [EntriesPerNode]int, // entry indices
	size:     int,
	children: int, // start index of child node indices, child nodes are contiguous
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
	free_list:   [MaxEntries]int,
	free_count:  int,
	results:     [MaxResults]Entry(T),
}

Quadrant :: enum {
	None = -1,
	NW   = 0,
	NE   = 1,
	SW   = 2,
	SE   = 3,
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
	assert(qt.nodes[node_idx].children == 0, "node already subdivided")
	if qt.node_count + 4 > int(MaxNodes) {
		log.infof("Quadtree nodes are full: %v / %v", qt.node_count, int(MaxNodes))
		return false
	}

	node := &qt.nodes[node_idx]
	half_width := node.bounds.width / 2
	half_height := node.bounds.height / 2
	x := node.bounds.x
	y := node.bounds.y

	// create 4 child nodes
	node.children = qt.node_count
	for i in 0 ..< 4 {
		child_idx := qt.node_count
		qt.node_count += 1

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
		}
	}

	// try to move entries into children
	if node.size > 0 {
		for i := node.size - 1; i >= 0; i -= 1 {
			entry_index := node.entries[i]
			entry := &qt.entries[entry_index]
			quadrant := get_quadrant(node, entry.rect)
			if quadrant == .None {
				continue
			}

			index := int(quadrant)
			child_node_idx := node.children + index

			// update entry back reference
			entry.node = child_node_idx

			// insert entry into child node
			child_node := &qt.nodes[node.children + index]
			child_node.entries[child_node.size] = entry_index
			child_node.size += 1

			// remove entry from current node
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

get_next_index :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
) -> int {
	if qt.free_count > 0 {
		qt.free_count -= 1
		return qt.free_list[qt.free_count]
	}

	index := qt.entry_count
	qt.entry_count += 1
	return index
}

insert :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	rect: Rectangle,
	data: T,
) -> (
	int,
	bool,
) {
	return insert_node(qt, 0, rect, data)
}

insert_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
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

	if qt.entry_count >= int(MaxEntries) && qt.free_count == 0 {
		// log.infof("Quadtree entries are full: %v / %v", qt.entry_count, int(MaxEntries))
		return 0, false
	}

	if node.size < SUBDIVISION_THRESHOLD && node.children == 0 {
		if node.size >= int(EntriesPerNode) {
			log.infof("Node %v is full", node.bounds)
			return 0, false
		}
		index := get_next_index(qt)
		node.entries[node.size] = index
		qt.entries[index] = {rect, data, node_idx}
		node.size += 1
		return index, true
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
		index := int(quadrant)
		return insert_node(qt, node.children + index, rect, data)
	}

	// insert into current node
	if node.size >= int(EntriesPerNode) {
		log.infof("Node %v is full", node.bounds)
		return 0, false
	}
	index := get_next_index(qt)
	qt.entries[index] = {rect, data, node_idx}
	node.entries[node.size] = index
	node.size += 1
	return index, true
}

remove :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
	index: int,
) -> bool {
	if index < 0 || index >= qt.entry_count {
		return false
	}

	entry := &qt.entries[index]
	node := &qt.nodes[entry.node]

	for i := node.size - 1; i >= 0; i -= 1 {
		if node.entries[i] == index {
			node.entries[i] = node.entries[node.size - 1]
			node.size -= 1
			qt.free_list[qt.free_count] = index
			qt.free_count += 1
			return true
		}
	}

	return false
}

update :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $EntriesPerNode, $MaxResults, $T),
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

	if node.children != 0 {
		for child_idx in 0 ..< 4 {
			result_count = query_rectangle_node(qt, node.children + child_idx, rect, result_count)
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

	if node.children != 0 {
		for child_idx in 0 ..< 4 {
			result_count = query_point_node(qt, node.children + child_idx, x, y, result_count)
		}
	}

	return result_count
}
