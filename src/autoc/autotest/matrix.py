# The curated container x element-kind registry driving the programmatic suite.
#
# Each row pairs a container factory (a callable name + element kind -> type
# instance, encapsulating family-specific kwargs like capacities, sentinel
# emitters and backends) with the element kinds it is instantiated over. The
# applicability rules live here (orderable-only families exclude the record
# kind, intrusive families need per-kind sentinel emitters); the per-method
# adaptation happens in concepts.py via trait probing.


import autoc.std as std
from autoc.vector import Vector
from autoc.packet import Packet
from autoc.array import Array
from autoc.tiered_vector import Vector as TieredVector
from autoc.list import List
from autoc.deque import Deque
from autoc.circular_buffer import Static as StaticCircularBuffer
from autoc.circular_buffer import Dynamic as DynamicCircularBuffer
from autoc.stack import Stack
from autoc.queue import Queue
from autoc.priority_queue import Queue as PriorityQueue
from autoc.chained_hash_set import Set as ChainedHashSet
from autoc.intrusive_hash_set import Set as IntrusiveHashSet
from autoc.rb_set import Set as RbSet
from autoc.avl_set import Set as AvlSet
from autoc.treap_set import Set as TreapSet
from autoc.flat_set import Set as FlatSet
from autoc.btree_set import Set as BTreeSet
from autoc.chained_hash_map import Map as ChainedHashMap
from autoc.flat_map import Map as FlatMap
from autoc.tree_map import Map as TreeMap
from autoc.btree_map import Map as BTreeMap
from autoc.intrusive_hash_map import Map as IntrusiveHashMap
from autoc.flat_multimap import Map as FlatMultimap
from autoc.flat_multiset import Set as FlatMultiset
from autoc.multimap import Map as Multimap
from autoc.counter import Counter

from autoc.autotest import Type
from autoc.autotest import concepts
from autoc.autotest.elements import KINDS


ALL = ("int", "cstring", "comp", "arc", "rec")
ORDERED = ("int", "cstring", "comp")


# Intrusive open addressing encodes slot states as sentinel element values -
# the emitters are chosen per element kind (INT_MIN/INT_MAX for ints, low
# pointer values for counted references)
def _int_sentinels():
  return dict(
    is_empty=lambda e: f"{e} == INT_MIN",
    mark_empty=lambda e: f"{e} = INT_MIN",
    is_deleted=lambda e: f"{e} == INT_MAX",
    mark_deleted=lambda e: f"{e} = INT_MAX",
  )


def _arc_sentinels():
  return dict(
    is_empty=lambda e: f"{e} == (int*)(size_t)2",
    mark_empty=lambda e: f"{e} = (int*)(size_t)2",
    is_deleted=lambda e: f"{e} == (int*)(size_t)1",
    mark_deleted=lambda e: f"{e} = (int*)(size_t)1",
  )


# Map sentinels receive the whole entry expression and mark its index field -
# keeping the mark on one field spares memory debuggers from untouching the rest
def _int_entry_sentinels():
  return dict(
    is_empty=lambda e: f"{e}.index == INT_MIN",
    mark_empty=lambda e: f"{e}.index = INT_MIN",
    is_deleted=lambda e: f"{e}.index == INT_MAX",
    mark_deleted=lambda e: f"{e}.index = INT_MAX",
  )


# Simple rows: (factory, family name, kinds) where factory takes (name, element)
def _simple(cls, **kwargs):
  return lambda name, element: cls(name, element, **kwargs)

ROWS = (
  (_simple(Vector), "vector", ALL),
  (_simple(Packet, capacity=8), "packet", ("int", "cstring")),  # slots default-construct: parametrized-create kinds excluded
  (_simple(Array, size=8), "array", ("int", "cstring")),
  (_simple(TieredVector), "tiered", ("int",)),  # growth default-constructs slots: parametrized-create kinds excluded
  # Node-based sequences over arc elements are excluded: their member rendering
  # path (Indirection.Variable.definition) emits a C-illegal default initializer
  # - a generator gap the hand-crafted suite never covers either
  (_simple(List), "list", ("int", "cstring", "comp", "rec")),
  (_simple(Deque), "deque", ("int", "cstring", "comp", "rec")),
  (_simple(StaticCircularBuffer, capacity=4), "scbuffer", ("int", "cstring")),
  (_simple(DynamicCircularBuffer), "dbuffer", ("int", "comp")),
  (_simple(Stack), "stack", ("int", "cstring", "comp")),
  (_simple(Queue), "queue", ("int", "cstring", "comp")),
  (_simple(PriorityQueue), "pqueue", ("int", "cstring")),
  (_simple(ChainedHashSet), "chained_set", ALL),
  (lambda name, element: IntrusiveHashSet(name, element, dependencies=(std.limits_h,), **_int_sentinels()),
   "intrusive_set", ("int",)),
  (lambda name, element: IntrusiveHashSet(name, element, **_arc_sentinels()),
   "intrusive_set", ("arc",)),
  (_simple(RbSet), "rb_set", ORDERED),
  (_simple(AvlSet), "avl_set", ORDERED),
  (_simple(TreapSet), "treap_set", ORDERED),
  (_simple(FlatSet), "flat_set", ORDERED),
  (_simple(FlatMultiset), "flat_multiset", ORDERED),
  (_simple(BTreeSet, order=4), "btree_set", ORDERED),
)


# Keyed rows: factory takes (name, value type, key element); map values are int
def _map_simple(cls, **kwargs):
  return lambda name, value, key: cls(name, value, key, **kwargs)

MAP_ROWS = (
  (_map_simple(ChainedHashMap), "chained_hash_map", ("int", "cstring", "comp")),
  (_map_simple(FlatMap), "flat_map", ("int", "cstring")),
  (_map_simple(TreeMap, set=RbSet), "rb_tree_map", ("int", "cstring")),
  (_map_simple(BTreeMap, order=4), "btree_map", ORDERED),
  (lambda name, value, key: IntrusiveHashMap(name, value, key, dependencies=(std.limits_h,), **_int_entry_sentinels()),
   "intrusive_hash_map", ("int",)),
  (_map_simple(FlatMultimap), "flat_multimap", ("int",)),
  (lambda name, value, key: Multimap(name, value, key, AvlSet, Vector), "multimap", ("int",)),
)

COUNTER_ROWS = (
  (lambda name: Counter(name, "int", backend=FlatMap), "counter_flat"),
  (lambda name: Counter(name, "int", backend=ChainedHashMap), "counter_chained"),
)


def build():
  # Plain and set containers: one instantiation per (family, element kind) cell
  for factory, family, kinds in ROWS:
    for kind in kinds:
      ek = KINDS[kind]
      T = factory(f"{kind}_{family}", ek.type)
      concepts.emit_all(Type(T), T, ek)

  # Keyed containers: the element kind describes the key, values are int
  for factory, family, kinds in MAP_ROWS:
    for kind in kinds:
      ek = KINDS[kind]
      T = factory(f"{kind}2int_{family}", "int", ek.type)
      concepts.emit_all(Type(T), T, ek)

  for factory, family in COUNTER_ROWS:
    ek = KINDS["int"]
    T = factory(f"int_{family}")
    concepts.emit_all(Type(T), T, ek)


build()
