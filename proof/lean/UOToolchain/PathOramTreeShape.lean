namespace UOToolchain

/-!
# The private scheme's AVL map: public shape

`path_oram_private_posmap_v1` keeps a map as an AVL tree of `capacity`
preallocated nodes in one Path ORAM tree; each node holds its children's
leaves, so the position map recurses through the tree. Its public shape
depends only on the capacity: the largest height of an AVL tree of
`capacity` nodes, the node accesses of a get and of a put, and the stash
bound. The runtime computes the same numbers (`path_oram_tree_avl_height`,
`path_oram_tree_get_accesses`, `path_oram_tree_put_accesses` and
`path_oram_tree_stash_bound` in `crates/uo-core/src/manifest.rs`).
-/

/-- The AVL height loop: while the smallest AVL tree of the next height,
`fib - 1` nodes, fits in `capacity`, count it and step the Fibonacci pair. -/
def pathOramTreeAvlHeightFrom (capacity : Nat) : Nat → Nat → Nat → Nat → Nat
  | 0, _, _, height => height
  | fuel + 1, fibPrev, fib, height =>
      if fib - 1 ≤ capacity then
        pathOramTreeAvlHeightFrom capacity fuel fib (fib + fibPrev) (height + 1)
      else
        height

/-- The largest height of an AVL tree of `capacity` nodes, counted in nodes:
the largest `h` whose smallest AVL tree, `F(h + 2) - 1` nodes, fits, and at
least 1. -/
def pathOramTreeAvlHeight (capacity : Nat) : Nat :=
  max (pathOramTreeAvlHeightFrom capacity (capacity + 2) 1 2 0) 1

/-- The node accesses of a get: one per level. -/
def pathOramTreeGetAccesses (capacity : Nat) : Nat :=
  pathOramTreeAvlHeight capacity

/-- The node accesses of a put: one per level to walk, one to pop the free
list, and two per level to rebalance. -/
def pathOramTreePutAccesses (capacity : Nat) : Nat :=
  3 * pathOramTreeAvlHeight capacity + 1

/-- The private scheme's stash bound for a Path ORAM stash bound limit: the
limit plus the nodes an operation returns to the stash, and at most the
capacity. -/
def pathOramTreeStashBoundWith (limit capacity : Nat) : Nat :=
  min (max capacity 1) (limit + pathOramTreePutAccesses capacity)

example : pathOramTreeAvlHeight 1 = 1 := by decide
example : pathOramTreeAvlHeight 16 = 5 := by decide
example : pathOramTreeAvlHeight 256 = 11 := by decide
example : pathOramTreeAvlHeight 4096 = 16 := by decide
example : pathOramTreeAvlHeight 16384 = 19 := by decide
example : pathOramTreeStashBoundWith 152 256 = 186 := by decide
example : pathOramTreeStashBoundWith 152 16384 = 210 := by decide

end UOToolchain
