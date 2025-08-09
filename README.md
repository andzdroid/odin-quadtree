# Quadtree for Odin

This is an implementation of quadtrees for Odin, with fixed-size data structure - no dynamic allocations.

The entire source is in `src/quadtree.odin`.

![Demo](demo/more.png)

## Usage

```odin
tree: qt.Quadtree(maxNodes, maxEntries, maxResults, YourDataType)
qt.init(&tree, {x, y, width, height})

// Insert
index, ok := qt.insert(&tree, {150, 200, 10, 10}, data)

// Update
index2, ok2 := qt.update(&tree, index, {160, 180, 10, 10}, data)
assert(index == index2, "Index does not change between updates")

// Remove
ok := qt.remove(&tree, index)

// Search
results := qt.query_point(&tree, x, y)
results = qt.query_rectangle(&tree, {x, y, width, height})
results = qt.query_circle(&tree, x, y, radius)
results = qt.query_nearest(&tree, x, y, k)

// Search with options
results = qt.query_rectangle(&tree, rect, qt.QueryRectangleOptions(int){
  max_results = 5,
  predicate = proc(entry: qt.Entry(int)) -> bool {
    return entry.data % 2 == 0
  },
})
results = qt.query_circle(&tree, x, y, radius, qt.QueryCircleOptions(int){
  max_results = 5,
  predicate = predicate
})
results = qt.query_point(&tree, x, y, qt.QueryPointOptions(int){
  max_results = 5,
  predicate = predicate,
})
results = qt.query_nearest(&tree, x, y, qt.QueryNearestOptions(int){
  max_results = 5,
  max_distance = f32(100),
  predicate = predicate
})

for entry in results {
  // entry.data is the same data that was inserted/updated
}

```

The Quadtree struct requires some parameters:

- **MaxNodes** - Each time an area is subdivided, 4 nodes are added. `(MaxNodes - 1)` should be a multiple of 4 (4 for each subdivision + 1 root node).
- **MaxEntries** - The max number of entries you will add to the tree.
- **MaxResults** - The max number of results you want to fetch from queries.
- **T** - this is the type of data you want to store with each entry.

## Search with predicates

You can pass a predicate to query functions to filter out entries while searching. This is especially useful when combined with nearest search.

Use the context pointer to pass extra data into the predicate function:

```odin
context.user_ptr = your_data
results = qt.query_rectangle(&tree, qt.Rectangle{}, proc(entry: qt.Entry(int)) -> bool {
  your_data := cast(^[]YourData)context.user_ptr
  return your_data[entry.data].field < 10
})
```

## Demo

See `demo/demo.odin` for a working example.

```
odin run demo
```

Point query:
![Point query](demo/point.png)

Rectangle query:
![Rectangle query](demo/rectangle.png)

Circle query:
![Circle query](demo/circle.png)

Predicate query:
![Predicate query](demo/predicate.png)

Nearest query:
![Nearest query](demo/nearest.png)

## Design decisions and optimizations

Nodes store the index of the first child node only. Nodes are contiguous, so the 4 children of a node are at index `node.children`, `node.children+1`, `node.children+2` and `node.children+3`.

Nodes store the index of the first entry only. Entries are stored as a doubly linked list. Changing from storing an array of entry indexes to a linked list reduced memory usage by 90%.

Entries are a doubly linked list instead of a singly linked list. This greatly speeds up the removal of entries. Removal is the fastest operation at around 20ns per op in my benchmark.

Bounds are stored with the node. I tried calculating bounds instead of storing them, and this reduced performance in exchange for a tiny savings in memory usage.

Freed entries are stored as a singly linked list, with the quadtree pointing to the head only. This means we don't need to keep track of every freed entry, only the latest one.

Subdivision threshold is not a customizable parameter. I saw no changes in performance with different thresholds.

Implementing the quadtree as a loose quadtree made no improvement to performance.

Entries that cross a boundary are stored on the parent instead of being duplicated in multiple child nodes. I never implemented storing duplicates so I can't compare the two. Storing on the parent feels much simpler.