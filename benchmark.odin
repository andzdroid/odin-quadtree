package benchmark

import qt "./src"
import "core:fmt"
import "core:math/rand"
import "core:time"

/*
Insert total:  621.989ms , average:  621ns
Query total:  1.208854s , average:  12.088µs
Remove total:  116.254ms , average:  116ns
*/

MAX_NODES :: 65_537
MAX_ENTRIES :: 1_000_000
MAX_ENTRIES_PER_NODE :: 1000
MAX_QUERY_RESULTS :: 1000

QUERY_ITERATIONS :: 100_000

Handle :: struct {
	index:      int,
	generation: int,
}

main :: proc() {
	tree := new(
		qt.Quadtree(MAX_NODES, MAX_ENTRIES, MAX_ENTRIES_PER_NODE, MAX_QUERY_RESULTS, Handle),
	)
	defer free(tree)

	qt.init(tree, {0, 0, 100000, 100000})

	// insert
	start := time.now()
	for i in 0 ..< MAX_ENTRIES {
		qt.insert(
			tree,
			{
				x = rand.float32_range(0, 100000),
				y = rand.float32_range(0, 100000),
				width = 10,
				height = 10,
			},
			Handle{index = i},
		)
	}
	elapsed := time.since(start)
	fmt.println("Insert total: ", elapsed, ", average: ", elapsed / time.Duration(MAX_ENTRIES))

	// query
	start = time.now()
	for i in 0 ..< QUERY_ITERATIONS {
		qt.query_rectangle(
			tree,
			{
				x = rand.float32_range(0, 100000),
				y = rand.float32_range(0, 100000),
				width = 100,
				height = 100,
			},
		)
	}
	elapsed = time.since(start)
	fmt.println("Query total: ", elapsed, ", average: ", elapsed / time.Duration(QUERY_ITERATIONS))

	// remove
	start = time.now()
	for i in 0 ..< MAX_ENTRIES {
		qt.remove(tree, i)
	}
	elapsed = time.since(start)
	fmt.println("Remove total: ", elapsed, ", average: ", elapsed / time.Duration(MAX_ENTRIES))
}
