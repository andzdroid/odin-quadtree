package benchmark

import qt "./src"
import "core:fmt"
import "core:math/rand"
import "core:time"

/*
Array:
Size of tree: 547.8222 MB
Insert total:  644.153ms , average:  644ns
Query total:  1.213059s , average:  12.13µs
Remove total:  123.191ms , average:  123ns

Double linked list:
Size of tree: 55.959229 MB
Insert total:  500.106ms , average:  500ns
Query total:  1.204676s , average:  12.046µs
Remove total:  22.838ms , average:  22ns

Nearest search:
Size of tree: 56.012634 MB
Insert total:  513.739ms , average:  513ns
Rectangle query results (no predicate):  120775 , total:  1.201933s , average:  12.019µs
Rectangle query results with predicate:  60078 , total:  1.159971s , average:  11.599µs
Nearest query:  1000000 , total:  2.6043s , average:  260.43µs
Remove total:  22.136ms , average:  22ns
*/

MAX_NODES :: 65_537
MAX_ENTRIES :: 1_000_000
MAX_QUERY_RESULTS :: 1000

QUERY_ITERATIONS :: 100_000

Handle :: struct {
	index:      int,
	generation: int,
}

main :: proc() {
	tree := new(qt.Quadtree(MAX_NODES, MAX_ENTRIES, MAX_QUERY_RESULTS, Handle))
	defer free(tree)

	qt.init(tree, {0, 0, 100000, 100000})

	fmt.println("Size of tree:", (f32(size_of(tree^)) / 1024 / 1024), "MB")

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
	count := 0
	for i in 0 ..< QUERY_ITERATIONS {
		results := qt.query_rectangle(
			tree,
			{
				x = rand.float32_range(0, 100000),
				y = rand.float32_range(0, 100000),
				width = 100,
				height = 100,
			},
		)
		count += len(results)
	}
	elapsed = time.since(start)
	fmt.println(
		"Rectangle query results (no predicate): ",
		count,
		", total: ",
		elapsed,
		", average: ",
		elapsed / time.Duration(QUERY_ITERATIONS),
	)

	start = time.now()
	count = 0
	for i in 0 ..< QUERY_ITERATIONS {
		results := qt.query_rectangle_with_predicate(
			tree,
			{
				x = rand.float32_range(0, 100000),
				y = rand.float32_range(0, 100000),
				width = 100,
				height = 100,
			},
			proc(entry: qt.Entry(Handle)) -> bool {
				return entry.data.index % 2 == 0
			},
		)
		count += len(results)
	}
	elapsed = time.since(start)
	fmt.println(
		"Rectangle query results with predicate: ",
		count,
		", total: ",
		elapsed,
		", average: ",
		elapsed / time.Duration(QUERY_ITERATIONS),
	)

	start = time.now()
	count = 0
	for i in 0 ..< 10000 {
		results := qt.query_nearest(
			tree,
			rand.float32_range(0, 100000),
			rand.float32_range(0, 100000),
			{max_results = 100, max_distance = 10000},
		)
		count += len(results)
	}
	elapsed = time.since(start)
	fmt.println(
		"Nearest query: ",
		count,
		", total: ",
		elapsed,
		", average: ",
		elapsed / time.Duration(10000),
	)

	// remove
	start = time.now()
	for i in 0 ..< MAX_ENTRIES {
		qt.remove(tree, i)
	}
	elapsed = time.since(start)
	fmt.println("Remove total: ", elapsed, ", average: ", elapsed / time.Duration(MAX_ENTRIES))
}
