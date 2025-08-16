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
	bounds:      Rectangle,
	center:      [2]f32, // pre-computed center
	entries:     int, // index of first entry, doubly linked list
	entry_count: int,
	children:    int, // start index of child node indices, child nodes are contiguous
}

Quadtree :: struct($MaxNodes: int, $MaxEntries: int, $MaxResults: int, $T: typeid) {
	nodes:       [MaxNodes]Node,
	entries:     [MaxEntries]Entry(T),
	node_count:  int,
	entry_count: int,
	next_free:   int, // free list is singly linked
	results:     [MaxResults]Entry(T),
	temp:        [MaxResults]Entry(T), // used for sorting for nearest queries
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
		center = {bounds.x + bounds.width / 2, bounds.y + bounds.height / 2},
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
		bounds := get_quadrant_bounds(node.bounds, Quadrant(i))
		qt.nodes[child_idx] = {
			bounds = bounds,
			center = {bounds.x + bounds.width / 2, bounds.y + bounds.height / 2},
		}
	}

	// try to move entries into children
	if node.entry_count > 0 {
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
			child_node.entry_count += 1
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

			node.entry_count -= 1

			current_index = next_index
		}
	}

	return true
}

get_quadrant :: proc(node: ^Node, rect: Rectangle) -> Quadrant {
	top := rect.y + rect.height < node.center.y
	right := rect.x >= node.center.x
	if top && right do return .NE

	left := rect.x + rect.width < node.center.x
	if top && left do return .NW

	bottom := rect.y >= node.center.y
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
		log.infof("Quadtree entries are full: %v / %v", qt.entry_count, int(MaxEntries))
		return 0, false
	}

	if node.entry_count < SUBDIVISION_THRESHOLD && node.children == 0 {
		return insert_entry(qt, node_idx, rect, data)
	}

	reached_node_limit := qt.node_count + 4 > int(MaxNodes)
	if node.children == 0 && !reached_node_limit {
		if !subdivide(qt, node_idx) {
			return 0, false
		}
	}

	// insert into child node
	quadrant := get_quadrant(node, rect)
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
	node.entry_count += 1
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
	node.entry_count -= 1
	entry.next = qt.next_free
	entry.prev = 0
	entry.node = 0
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

QueryRectangleOptions :: struct {
	max_results: int,
}

query_rectangle :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	rect: Rectangle,
	options: QueryRectangleOptions = {},
) -> []Entry(T) {
	count := query_rectangle_node(qt, 0, rect, options, nil, 0)
	return qt.results[:count]
}

query_rectangle_with_predicate :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	rect: Rectangle,
	predicate: proc(entry: Entry(T)) -> bool,
	options: QueryRectangleOptions = {},
) -> []Entry(T) {
	count := query_rectangle_node(qt, 0, rect, options, predicate, 0)
	return qt.results[:count]
}

query_rectangle_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	rect: Rectangle,
	options: QueryRectangleOptions,
	predicate: proc(entry: Entry(T)) -> bool,
	count: int,
) -> int {
	max_results := options.max_results != 0 ? min(options.max_results, MaxResults) : MaxResults
	if count >= max_results {
		return count
	}

	node := &qt.nodes[node_idx]
	if !intersects(node.bounds, rect) {
		return count
	}

	result_count := count
	current_index := node.entries
	for current_index != 0 {
		if result_count >= max_results {
			break
		}

		entry := qt.entries[current_index]
		if !intersects(rect, entry.rect) {
			current_index = entry.next
			continue
		}

		if predicate != nil && !predicate(entry) {
			current_index = entry.next
			continue
		}

		qt.results[result_count] = entry
		result_count += 1
		current_index = entry.next
	}

	if node.children != 0 {
		for child_idx in 0 ..< 4 {
			result_count = query_rectangle_node(
				qt,
				node.children + child_idx,
				rect,
				options,
				predicate,
				result_count,
			)
		}
	}

	return result_count
}

QueryCircleOptions :: struct {
	max_results: int,
}

query_circle :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	center_x, center_y, radius: f32,
	options: QueryCircleOptions = {},
) -> []Entry(T) {
	assert(radius >= 0, "radius must be non-negative")
	count := query_circle_node(qt, 0, center_x, center_y, radius, options, nil, 0)
	return qt.results[:count]
}

query_circle_with_predicate :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	center_x, center_y, radius: f32,
	predicate: proc(entry: Entry(T)) -> bool,
	options: QueryCircleOptions = {},
) -> []Entry(T) {
	assert(radius >= 0, "radius must be non-negative")
	count := query_circle_node(qt, 0, center_x, center_y, radius, options, predicate, 0)
	return qt.results[:count]
}

query_circle_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	center_x, center_y, radius: f32,
	options: QueryCircleOptions,
	predicate: proc(entry: Entry(T)) -> bool,
	count: int,
) -> int {
	max_results := options.max_results != 0 ? min(options.max_results, MaxResults) : MaxResults
	if count >= max_results {
		return count
	}

	node := &qt.nodes[node_idx]
	if !intersects(node.bounds, center_x, center_y, radius) {
		return count
	}

	result_count := count
	current_index := node.entries
	for current_index != 0 {
		if result_count >= max_results {
			break
		}

		entry := qt.entries[current_index]
		if !intersects(entry.rect, center_x, center_y, radius) {
			current_index = entry.next
			continue
		}

		if predicate != nil && !predicate(entry) {
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
				options,
				predicate,
				result_count,
			)
		}
	}

	return result_count
}

QueryPointOptions :: struct {
	max_results: int,
}

query_point :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	x, y: f32,
	options: QueryPointOptions = {},
) -> []Entry(T) {
	count := query_point_node(qt, 0, x, y, options, nil, 0)
	return qt.results[:count]
}

query_point_with_predicate :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	x, y: f32,
	predicate: proc(entry: Entry(T)) -> bool,
	options: QueryPointOptions = {},
) -> []Entry(T) {
	count := query_point_node(qt, 0, x, y, options, predicate, 0)
	return qt.results[:count]
}

query_point_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	x, y: f32,
	options: QueryPointOptions,
	predicate: proc(entry: Entry(T)) -> bool,
	count: int,
) -> int {
	max_results := options.max_results != 0 ? min(options.max_results, MaxResults) : MaxResults
	if count >= max_results {
		return count
	}

	node := &qt.nodes[node_idx]
	if !contains(node.bounds, x, y) {
		return count
	}

	result_count := count
	current_index := node.entries
	for current_index != 0 {
		if result_count >= max_results {
			break
		}

		entry := qt.entries[current_index]
		if !contains(entry.rect, x, y) {
			current_index = entry.next
			continue
		}

		if predicate != nil && !predicate(entry) {
			current_index = entry.next
			continue
		}

		qt.results[result_count] = entry
		result_count += 1
		current_index = entry.next
	}

	if node.children != 0 {
		for child_idx in 0 ..< 4 {
			result_count = query_point_node(
				qt,
				node.children + child_idx,
				x,
				y,
				options,
				predicate,
				result_count,
			)
		}
	}

	return result_count
}

QueryNearestOptions :: struct {
	max_results:  int,
	max_distance: f32,
}

query_nearest :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	x, y: f32,
	options: QueryNearestOptions = {},
) -> []Entry(T) {
	count := query_nearest_node(qt, 0, x, y, options, nil, 0)
	sort_by_distance(qt, qt.results[:count], x, y)
	return qt.results[:count]
}

query_nearest_with_predicate :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	x, y: f32,
	predicate: proc(entry: Entry(T)) -> bool,
	options: QueryNearestOptions = {},
) -> []Entry(T) {
	count := query_nearest_node(qt, 0, x, y, options, predicate, 0)
	sort_by_distance(qt, qt.results[:count], x, y)
	return qt.results[:count]
}

query_nearest_node :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	node_idx: int,
	x, y: f32,
	options: QueryNearestOptions,
	predicate: proc(entry: Entry(T)) -> bool,
	count: int,
) -> int {
	max_results := options.max_results != 0 ? min(options.max_results, MaxResults) : MaxResults
	max_distance := options.max_distance != 0 ? options.max_distance * options.max_distance : 0

	node := &qt.nodes[node_idx]

	result_count := count
	current_index := node.entries
	for current_index != 0 {
		entry := qt.entries[current_index]
		if predicate != nil && !predicate(entry) {
			current_index = entry.next
			continue
		}
		if max_distance != 0 && distance_to_rect(entry.rect, x, y) > max_distance {
			current_index = entry.next
			continue
		}
		result_count = heap_insert(qt, entry, x, y, result_count, max_results)
		current_index = entry.next
	}

	if node.children != 0 {
		// Sort child nodes by distance to target point
		child_order: [4]struct {
			idx:      int,
			distance: f32,
		}
		child_order = {
			{idx = 0, distance = distance_to_rect(qt.nodes[node.children].bounds, x, y)},
			{idx = 1, distance = distance_to_rect(qt.nodes[node.children + 1].bounds, x, y)},
			{idx = 2, distance = distance_to_rect(qt.nodes[node.children + 2].bounds, x, y)},
			{idx = 3, distance = distance_to_rect(qt.nodes[node.children + 3].bounds, x, y)},
		}
		for i in 1 ..< 4 {
			key := child_order[i]
			j := i - 1
			for j >= 0 && child_order[j].distance > key.distance {
				child_order[j + 1] = child_order[j]
				j -= 1
			}
			child_order[j + 1] = key
		}

		for child in child_order {
			if result_count > max_results {
				continue
			}

			if max_distance != 0 && child.distance > max_distance {
				continue
			}

			if result_count == max_results {
				max_dist := distance_to_rect(qt.results[0].rect, x, y)
				if child.distance >= max_dist {
					continue
				}
			}

			result_count = query_nearest_node(
				qt,
				node.children + child.idx,
				x,
				y,
				options,
				predicate,
				result_count,
			)
		}
	}

	return result_count
}

distance_to_rect :: proc(rect: Rectangle, x, y: f32) -> f32 {
	dx := math.max(0, math.max(rect.x - x, x - (rect.x + rect.width)))
	dy := math.max(0, math.max(rect.y - y, y - (rect.y + rect.height)))
	return dx * dx + dy * dy
}

heap_insert :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	entry: Entry(T),
	x, y: f32,
	count: int,
	k: int,
) -> int {
	distance := distance_to_rect(entry.rect, x, y)

	if count < k {
		qt.results[count] = entry
		heap_bubble_up(qt.results[:count + 1], count, x, y)
		return count + 1
	}

	max_dist := distance_to_rect(qt.results[0].rect, x, y)
	if distance < max_dist {
		qt.results[0] = entry
		heap_bubble_down(qt.results[:k], 0, x, y)
	}

	return k
}

heap_bubble_up :: proc(heap: []Entry($T), index: int, x, y: f32) {
	if index == 0 do return

	parent := (index - 1) / 2
	if distance_to_rect(heap[index].rect, x, y) > distance_to_rect(heap[parent].rect, x, y) {
		heap[index], heap[parent] = heap[parent], heap[index]
		heap_bubble_up(heap, parent, x, y)
	}
}

heap_bubble_down :: proc(heap: []Entry($T), index: int, x, y: f32) {
	size := len(heap)
	largest := index
	left := 2 * index + 1
	right := 2 * index + 2

	if left < size &&
	   distance_to_rect(heap[left].rect, x, y) > distance_to_rect(heap[largest].rect, x, y) {
		largest = left
	}

	if right < size &&
	   distance_to_rect(heap[right].rect, x, y) > distance_to_rect(heap[largest].rect, x, y) {
		largest = right
	}

	if largest != index {
		heap[index], heap[largest] = heap[largest], heap[index]
		heap_bubble_down(heap, largest, x, y)
	}
}

sort_by_distance :: proc(
	qt: ^Quadtree($MaxNodes, $MaxEntries, $MaxResults, $T),
	entries: []Entry(T),
	x, y: f32,
) {
	if len(entries) <= 1 do return
	merge_sort_by_distance(entries, qt.temp[:len(entries)], x, y)
}

merge_sort_by_distance :: proc(entries: []Entry($T), temp: []Entry(T), x, y: f32) {
	if len(entries) <= 1 do return
	mid := len(entries) / 2
	left := entries[:mid]
	right := entries[mid:]
	merge_sort_by_distance(left, temp[:len(left)], x, y)
	merge_sort_by_distance(right, temp[len(left):], x, y)
	merge_by_distance(entries, left, right, temp, x, y)
}

merge_by_distance :: proc(
	result: []Entry($T),
	left: []Entry(T),
	right: []Entry(T),
	temp: []Entry(T),
	x, y: f32,
) {
	i, j, k := 0, 0, 0

	for i < len(left) && j < len(right) {
		left_dist := distance_to_rect(left[i].rect, x, y)
		right_dist := distance_to_rect(right[j].rect, x, y)

		if left_dist <= right_dist {
			temp[k] = left[i]
			i += 1
		} else {
			temp[k] = right[j]
			j += 1
		}
		k += 1
	}

	for i < len(left) {
		temp[k] = left[i]
		i += 1
		k += 1
	}

	for j < len(right) {
		temp[k] = right[j]
		j += 1
		k += 1
	}

	copy(result, temp[:len(result)])
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
