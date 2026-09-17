# Design principles {#design}

`autoc` is small enough that its whole behaviour can be described by one protocol, one range
abstraction and a handful of container strategies. This chapter explains the ideas the
reference manual assumes.

## The value-semantics protocol

Everything `autoc` generates — containers, records, references, variants — is a *value type*
with a regular representation. Concretely, a type `T` implements as many of these operations
as its element types allow:

| Operation | Contract |
|---|---|
| `T_create(T* target)` | leave `target` in a valid, empty/default state |
| `T_destroy(T* target)` | release the resources owned by `target` |
| `T_copy(T* target, const T* source)` | make `target` an independent duplicate of `source` |
| `T_move(T* target, T* source)` | transfer ownership to `target`; leave `source` pristine |
| `T_swap(T* left, T* right)` | exchange the representations of two complete values |
| `T_equal(const T* l, const T* r)` | equality, `int` result |
| `T_compare(const T* l, const T* r)` | ordering, negative/zero/positive `int` result |
| `T_hash(const T* target)` | hash value consistent with `T_equal` |

The operations are *derived from the presence of the definitions*: a type carries exactly the
operations it can actually implement and nothing else. A container of a non-copyable element
is itself non-copyable; a set of a non-hashable element has no `hash`. The reference manual
shows these conditional operations too — where an operation is inapplicable it simply does
not appear.

Two weaker traits relieve the pressure on element types:

- **Zero-initializability.** If the all-zero representation of the type is a valid pristine
  state, bulk allocation can default-construct by zeroing memory instead of running a loop.
- **Swappability.** Swapping is defined even for ranges and other non-owning cursors, where
  it is indistinguishable from copying, and is used to derive the move.

The **move is derived** whenever the type can manufacture a pristine shell (default
construction) and exchange representations (swap): `move` becomes *create-then-swap*. Types
with a cheaper transfer supply their own. This is why `derived_move`-style types work with no
explicit `move` at all.

## Ranges

Iteration is expressed with *ranges*: small, non-owning, copyable cursors over a container.
Every sequence and every set and map has a nested range type, named after the container —
`List<T>::Range` for @ref List, `ChainedHashMap<K, V>::Range` for @ref ChainedHashMap — with
the C spelling `ListRange`, `ChainedHashMapRange`.

A range exposes exactly the operations its access pattern supports:

| Range kind | Operations |
|---|---|
| `Input` | `empty`, `front`, `front_view`, `move_front` |
| `Forward` | adds `copy` — the cursor can be duplicated and kept |
| `Backward` | adds `back`, `back_view`, `move_back` |
| `Bidirectional` | forward and backward |
| `DirectAccess` | adds `get`/`view`/`size` — random access |

A range records *where* a traversal is, never *what* it owns: copying a range gives you an
independent iteration position, and the underlying container must outlive every range over
it. Because ranges implement the value protocol, they compose — a vector sort walks a range,
a set algorithm drains the range of its operand.

## Containers

The container strategies differ in what they guarantee, not just in performance:

- **Chained hash** (@ref ChainedHashSet, @ref ChainedHashMap) stores each element in a node
  reached from a bucket. There are no sentinel values, element addresses are stable across
  insertions, and the default hash and equality of the element are used. This is the safe
  default.
- **Open addressing** (@ref IntrusiveHashSet, @ref IntrusiveHashMap) stores the elements flat
  and marks empty and deleted slots with sentinel values supplied by the element type. It is
  the most cache-friendly layout, at the cost of requiring the element to reserve two
  distinguishable states.
- **Treap** (@ref TreapSet, @ref TreapMap) is a randomized search tree — an ordered container:
  it iterates in sorted order, supports the ordering-based operations and gives the expected
  `O(log n)` insert, erase and search. The maps over the treap support lexicographic
  comparison.
- **Sequences** (@ref List, @ref Deque, @ref Vector, @ref TieredVector) trade access pattern
  against allocation behaviour: forward-linked, doubly-linked, contiguous and chunked
  respectively. @ref PriorityQueue is a binary heap which consumes its elements in priority
  order.

## Memory, hashing and determinism

- **Memory is explicit.** Containers allocate through a manager; the generated code uses
  `malloc`/`free` with no global allocator state, so several modules can coexist.
- **Hashing is incremental.** Container hashes combine element hashes through a seeded,
  order-sensitive (or order-insensitive for unordered containers) accumulator, so the hash of
  a container reflects the hashes of its elements.
- **Generation is deterministic.** Entities are emitted in a stable topological order, so
  re-running the generator over unchanged definitions produces identical output. This is what
  makes the digest-based regeneration in `add_autoc_module()` reliable.
- **References are optional.** @ref Arc provides reference counting for shared instances;
  @ref Raw is a plain unmanaged pointer. Both speak the same value protocol as everything
  else, so they can be container elements.