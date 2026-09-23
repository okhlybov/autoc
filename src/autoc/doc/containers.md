# Container catalog {#containers}

Every container below is documented in this manual as a single generic type, instantiated
with the placeholders `T` and `K` (see @ref index). The *Python module* is what you
import in your module script; the *type* is the class you instantiate with a concrete C type.

## Sequences

| Module | Type | Documented as | Range | Notes |
|---|---|---|---|---|
| `autoc.list` | `List` | `List<T>` | `List<T>::Range` (forward) | singly linked; `O(1)` push/pop at the front |
| `autoc.deque` | `Deque` | `Deque<T>` | `Deque<T>::Range` (bidirectional) | doubly linked; both ends are `O(1)` |
| `autoc.vector` | `Vector` | `Vector<T>` | `Vector<T>::Range` (direct access) | contiguous dynamic storage, amortized `O(1)` push/pop, indexed access, sorting and binary search; optional inline capacity for small buffer optimization |
| `autoc.array` | `Array` | `Array<T, N>` | `Array<T, N>::Range` (direct access) | fixed size, stack-allocated contiguous C array, zero heap allocation |
| `autoc.static_vector` | `StaticVector` | `StaticVector<T, N>` | `StaticVector<T, N>::Range` (direct access) | fixed capacity, stack-allocated, zero heap allocation; backed by variant |
| `autoc.tiered_vector` | `TieredVector` | `TieredVector<T>` | `TieredVector<T>::Range` (direct access) | chunked; amortized `O(1)` append with stable addresses |
| `autoc.stack` | `Stack` | `Stack<T>` | `Stack<T>::Range` (forward) | LIFO adapter over the list |
| `autoc.queue` | `Queue` | `Queue<T>` | `Queue<T>::Range` (forward) | FIFO adapter over the deque |
| `autoc.priority_queue` | `PriorityQueue` | `PriorityQueue<T>` | — | binary heap; `pop` yields the greatest element, duplicates allowed |
| `autoc.string` | `String` | `String<char>` | `String<char>::Range` (direct access) | string as an index→character map; variadic formatted output (`format`) |
| `autoc.string_buffer` | `StringBuffer` | `StringBuffer<char>` | — | append-optimized string buffer with scratch accumulation and lazy joining |

## Sets

| Module | Type | Documented as | Range | Notes |
|---|---|---|---|---|
| `autoc.chained_hash_set` | `Set` | `ChainedHashSet<T>` | forward | bucket chaining; no sentinels, stable element addresses, safe default |
| `autoc.intrusive_hash_set` | `Set` | `IntrusiveHashSet<T>` | forward | flat open addressing; needs sentinel values for the element type |
| `autoc.treap_set` | `Set` | `TreapSet<T>` | forward | ordered; iterates sorted, supports the algebraic set operations |
| `autoc.set` | `Set` | — | — | abstract interface shared by the set implementations |

## Maps

| Module | Type | Documented as | Range | Notes |
|---|---|---|---|---|
| `autoc.chained_hash_map` | `Map` | `ChainedHashMap<K, T>` | forward | bucket chaining over an internal entry set |
| `autoc.intrusive_hash_map` | `Map` | `IntrusiveHashMap<K, T>` | forward | flat open addressing; entries carry the sentinels |
| `autoc.treap_map` | `Map` | `TreapMap<K, T>` | forward | ordered by key; supports lexicographic comparison |
| `autoc.map` | `Map` | — | — | abstract interface shared by the map implementations |
| `autoc.hash_map` | `_Entry` | — | — | shared key→value entry record used by the map implementations |

## Value types

| Module | Type | Documented as | Notes |
|---|---|---|---|
| `autoc.bitset` | `BitSet` | `BitSet<N>` | fixed-size inline bit array; set algebra, popcount, zero heap allocation |
| `autoc.record` | `Record` | `Record` | user-defined aggregate of named fields, with generated getters/setters |
| `autoc.variant` | `Variant` | `Variant` | union holding one value out of a predefined set of types |
| `autoc.reference` | `Counted` | `Counted<T>` | reference-counted shared instance |
| `autoc.reference` | `Raw` | `Raw<T>` | unmanaged handle to a manually managed instance |
| `autoc.range` | `Input`/`Forward`/`Backward`/`Bidirectional`/`DirectAccess` | — | the iteration abstractions the container ranges are built from |

## Choosing a container

1. **Do you need indexed access?** Use @ref Array when size is fixed, or @ref Vector
   for dynamic resizing (with optional small buffer optimization via inline capacity),
   or @ref StaticVector when capacity is bounded and zero heap allocation is required,
   or @ref TieredVector when the buffer grows large or grows often and you need stable element addresses.
2. **Do you need to insert or remove at both ends?** Use @ref Deque; the adapters
   @ref Stack and @ref Queue are the LIFO/FIFO specializations of that pattern.
3. **Do you only touch the front in FIFO-ish fashion and want minimal bookkeeping?** Use @ref List.
4. **Do you consume elements in priority order?** Use @ref PriorityQueue.
5. **Do you need uniqueness with the element's own hash and equality?** Use
   @ref ChainedHashSet (the safe default) or @ref IntrusiveHashSet when the element type can
   reserve two sentinel states and the flat layout matters.
6. **Do you need the elements in sorted order, or ordering-based queries?** Use @ref TreapSet.
7. **Do you map keys to values?** Pick the map in the same family as the set you would have
   picked — @ref ChainedHashMap, @ref IntrusiveHashMap or @ref TreapMap.
8. **Do you need shared ownership of an element?** Use @ref Counted (or @ref Raw for manual
   lifetime management) — both work as container elements.
9. **Do you need a compact set of flags, booleans, or small integer universe?** Use
   @ref BitSet for zero-heap, fixed-capacity bitwise set algebra.

All concrete containers in one module share a single generated header, and each brings its
own group in this manual, so the operations of `ChainedHashSet` and `IntrusiveHashSet` never
have to be guessed: they are documented side by side.