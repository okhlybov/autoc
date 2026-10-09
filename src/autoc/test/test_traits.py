import unittest
from autoc.core import _Traitful, Composite, Primitive, TraitError, _Named, IntersectionType, Comparable, Orderable, Hashable, Copyable, satisfies, require, enforced
from autoc.ordered import Ordered
from autoc.hashed import Hashed
from autoc.set import Set
from autoc.multiset import Multiset
from autoc.mapping import Mapping
from autoc.insertable import Insertable
from autoc.chained_hash_set import Set as ChainedHashSet
from autoc.intrusive_hash_set import Set as IntrusiveHashSet
from autoc.btree_set import Set as BTreeSet
from autoc.avl_set import Set as AVLSet
from autoc.rb_set import Set as RBSet
from autoc.treap_set import Set as TreapSet
from autoc.flat_set import Set as FlatSet
from autoc.flat_multiset import Set as FlatMultiset
from autoc.chained_hash_map import Map as ChainedHashMap
from autoc.intrusive_hash_map import Map as IntrusiveHashMap
from autoc.tree_map import Map as TreeMap
from autoc.btree_map import Map as BTreeMap
from autoc.flat_map import Map as FlatMap
from autoc.flat_multimap import Map as FlatMultimap
from autoc.vector import Vector
from autoc.list import List
from autoc.deque import Deque
from autoc.array import Array
from autoc.tiered_vector import Vector as TieredVector
from autoc.circular_buffer import Static as StaticCircularBuffer, Dynamic as DynamicCircularBuffer
from autoc.priority_queue import Queue as PriorityQueue
from autoc.counter import Counter
from autoc.multimap import Map as Multimap
from autoc.queue import Queue
from autoc.stack import Stack


# Custom non-comparable, non-hashable, non-orderable composite type
class OpaqueType(Composite):

  def __init__(self, name="opaque_t"):
    super().__init__(name)

  def __setup__(self):
    super().__setup__()
    # Define create, copy, destroy so it's a valid copyable type
    with self.create as f:
      f.inline_code = "assert(target); target->value = 0;"
    with self.copy as f:
      f.inline_code = "assert(target); assert(source); target->value = source->value;"
    with self.destroy as f:
      f.inline_code = "assert(target);"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"struct {self.name} {{ int value; }};\n")


# Custom type with equality comparison only (no compare, no hash)
class ComparableOnlyType(Composite):

  def __init__(self, name="comp_only_t"):
    super().__init__(name)

  def __setup__(self):
    super().__setup__()
    with self.create as f:
      f.inline_code = "assert(target); target->value = 0;"
    with self.copy as f:
      f.inline_code = "assert(target); assert(source); target->value = source->value;"
    with self.destroy as f:
      f.inline_code = "assert(target);"
    with self.equal as f:
      f.inline_code = "return 1;"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"struct {self.name} {{ int value; }};\n")


class MockTraitful(_Traitful):

  def __init__(self, **traits):
    self._traits = traits

  @property
  def comparable(self):
    return self._traits.get("comparable", False)

  @property
  def orderable(self):
    return self._traits.get("orderable", False)

  @property
  def hashable(self):
    return self._traits.get("hashable", False)

  @property
  def copyable(self):
    return self._traits.get("copyable", False)

  @property
  def moveable(self):
    return self._traits.get("moveable", False)

  @property
  def destructible(self):
    return self._traits.get("destructible", False)

  @property
  def default_constructible(self):
    return self._traits.get("default_constructible", False)

  @property
  def zero_initializable(self):
    return self._traits.get("zero_initializable", False)

  @property
  def emplaceable(self):
    return self._traits.get("emplaceable", False)


class MockInquirer(_Named):

  def __init__(self, name, diagnostics=None):
    super().__init__(name)
    if diagnostics is not None:
      self._diagnostics = diagnostics


class TestTraits(unittest.TestCase):

  def test_traitful_enforcers_success(self):
    inq = MockInquirer("ctx", "Context")
    t = MockTraitful(comparable=True, orderable=True, hashable=True, copyable=True)
    self.assertIs(t.require_comparable(inq, "element type"), t)
    self.assertIs(t.require_orderable(inq, "element type"), t)
    self.assertIs(t.require_hashable(inq, "element type"), t)
    self.assertIs(t.require_copyable(inq, "element type"), t)
    self.assertIs(t.require_all(("comparable", "hashable"), inq, "element type"), t)
    self.assertIs(t.require_any(("comparable", "orderable"), inq, "element type"), t)

  def test_traitful_enforcers_failure(self):
    t = MockTraitful()
    with self.assertRaises(TraitError) as ctx:
      t.require_comparable(MockInquirer("s", "Set"), "element type")
    self.assertEqual(str(ctx.exception), "Set 's' requires the element type to be equality comparable")

    with self.assertRaises(TraitError) as ctx:
      t.require_orderable(MockInquirer("m", "Map"), "index type")
    self.assertEqual(str(ctx.exception), "Map 'm' requires the index type to be orderable")

    with self.assertRaises(TraitError) as ctx:
      t.require_hashable(MockInquirer("m", "Map"), "index type")
    self.assertEqual(str(ctx.exception), "Map 'm' requires the index type to be hashable")

    with self.assertRaises(TraitError) as ctx:
      t.require_copyable(MockInquirer("v", "Vector"), "element type")
    self.assertEqual(str(ctx.exception), "Vector 'v' requires the element type to be copyable")

    t_partial = MockTraitful(comparable=True, orderable=False)
    with self.assertRaises(TraitError) as ctx:
      t_partial.require_all(("comparable", "orderable"), MockInquirer("ms", "Multiset"), "element type")
    self.assertEqual(str(ctx.exception), "Multiset 'ms' requires the element type to be orderable")

    with self.assertRaises(TraitError) as ctx:
      t.require_any(("comparable", "hashable"), MockInquirer("c", "Container"), "element type")
    self.assertEqual(str(ctx.exception), "Container 'c' requires the element type to be equality comparable or hashable")

  def test_ordered_require(self):
    inq = MockInquirer("adapter", "Adapter")
    self.assertIs(FlatMap.require_ordered(inq), FlatMap)
    self.assertIs(TreeMap.require_ordered(inq), TreeMap)
    self.assertIs(BTreeMap.require_ordered(inq), BTreeMap)
    self.assertIs(FlatMultimap.require_ordered(inq), FlatMultimap)
    # Also via Ordered.require
    self.assertIs(Ordered.require(FlatMap, inq), FlatMap)

    with self.assertRaises(TraitError) as ctx:
      ChainedHashMap.require_ordered(inq)
    self.assertIn("requires an ordered component", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      Ordered.require(ChainedHashMap, inq)
    self.assertIn("requires an ordered component", str(ctx.exception))

  def test_hashed_require(self):
    inq = MockInquirer("adapter", "Adapter")
    self.assertIs(ChainedHashMap.require_hashed(inq), ChainedHashMap)
    self.assertIs(IntrusiveHashMap.require_hashed(inq), IntrusiveHashMap)
    self.assertIs(ChainedHashSet.require_hashed(inq), ChainedHashSet)
    self.assertIs(IntrusiveHashSet.require_hashed(inq), IntrusiveHashSet)
    # Also via Hashed.require
    self.assertIs(Hashed.require(ChainedHashMap, inq), ChainedHashMap)

    with self.assertRaises(TraitError) as ctx:
      TreeMap.require_hashed(inq)
    self.assertIn("requires a hashed component", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      Hashed.require(TreeMap, inq)
    self.assertIn("requires a hashed component", str(ctx.exception))

  def test_type_require(self):
    inq = MockInquirer("mm", "Multimap")
    self.assertIs(Set.require(AVLSet, inq), AVLSet)
    self.assertIs(Insertable.require(Vector, inq), Vector)
    self.assertIs(Mapping.require(FlatMap, inq), FlatMap)

    with self.assertRaises(TraitError) as ctx:
      Set.require(Vector, inq, "set backend")
    self.assertIn("requires a set backend - one claiming Set", str(ctx.exception))

    # Receiver-oriented require methods on container classes
    self.assertIs(AVLSet.require_set(inq), AVLSet)
    self.assertIs(Vector.require_insertable(inq), Vector)
    self.assertIs(Vector.require_traversable(inq), Vector)
    self.assertIs(FlatMap.require_mapping(inq), FlatMap)

    # Batch require_all with trait strings and types
    self.assertIs(AVLSet.require_all(("set", "ordered"), inq, "set backend"), AVLSet)
    self.assertIs(AVLSet.require_all((Set, Ordered), inq, "set backend"), AVLSet)

    with self.assertRaises(TraitError) as ctx:
      Vector.require_set(inq)
    self.assertIn("requires a set backend - one claiming Set", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      Vector.require_mapping(inq)
    self.assertIn("requires a mapping backend - one claiming Mapping", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      AVLSet.require_mapping(inq)
    self.assertIn("requires a mapping backend - one claiming Mapping", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      PriorityQueue.require_traversable(inq)
    self.assertIn("requires a collection backend - one claiming Traversable", str(ctx.exception))

    # Receiver-oriented require methods on container instances
    vec_inst = Vector("test_vec_inst", "int")
    self.assertIs(vec_inst.require_insertable(inq), vec_inst)

    set_inst = AVLSet("test_set_inst", "int")
    self.assertIs(set_inst.require_set(inq), set_inst)
    self.assertIs(set_inst.require_ordered(inq), set_inst)

    map_inst = FlatMap("test_map_inst", "int", "int")
    self.assertIs(map_inst.require_mapping(inq), map_inst)
    self.assertIs(map_inst.require_ordered(inq), map_inst)

  def test_negative_container_instantiations(self):
    opaque = OpaqueType("neg_opaque_t")
    # Priority queue demands orderable
    with self.assertRaises(TraitError) as ctx:
      PriorityQueue("neg_pq", opaque)
    self.assertEqual(str(ctx.exception), "Priority queue 'neg_pq' requires the element type to be orderable")

    # Set demands comparable
    with self.assertRaises(TraitError) as ctx:
      Set("neg_set", opaque)
    self.assertIn("requires the element type to be equality comparable", str(ctx.exception))

    # Multiset demands comparable
    with self.assertRaises(TraitError) as ctx:
      Multiset("neg_multiset", opaque)
    self.assertIn("requires the element type to be equality comparable", str(ctx.exception))

    comp_only = ComparableOnlyType("neg_comp_only_t")
    # Hash sets demand hashable
    with self.assertRaises(TraitError) as ctx:
      ChainedHashSet("neg_chs", comp_only)
    self.assertIn("requires the element type to be hashable", str(ctx.exception))

    # Tree and flat sets demand orderable
    with self.assertRaises(TraitError) as ctx:
      AVLSet("neg_avl", comp_only)
    self.assertIn("requires the element type to be orderable", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      FlatSet("neg_flat_set", comp_only)
    self.assertIn("requires the element type to be orderable", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      FlatMultiset("neg_flat_multiset", comp_only)
    self.assertIn("requires the element type to be orderable", str(ctx.exception))

    # Maps demand index traits
    with self.assertRaises(TraitError) as ctx:
      ChainedHashMap("neg_chm", "int", comp_only)
    self.assertIn("requires the index type to be hashable", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      TreeMap("neg_tm_key", "int", comp_only, AVLSet)
    self.assertIn("requires the index type to be orderable", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      TreeMap("neg_tm_backend", "int", "int", ChainedHashSet)
    self.assertIn("requires an ordered set backend", str(ctx.exception))

    # Tree map rejects an ordered collection that is NOT a Set (e.g. FlatMap)
    with self.assertRaises(TraitError) as ctx:
      TreeMap("neg_tm_not_set", "int", "int", FlatMap)
    self.assertIn("requires a set backend - one claiming Set; got Map", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      FlatMap("neg_fm", "int", comp_only)
    self.assertIn("requires the index type to be orderable", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      FlatMultimap("neg_fmm", "int", comp_only)
    self.assertIn("requires the index type to be orderable", str(ctx.exception))

    # Counter demands mapping backend
    with self.assertRaises(TraitError) as ctx:
      Counter("neg_cnt", "int", Vector)
    self.assertIn("requires a mapping backend - one claiming Mapping", str(ctx.exception))

    # Multimap demands set and insertable+traversable collection backends
    with self.assertRaises(TraitError) as ctx:
      Multimap("neg_mm_set", "int", "int", set=Vector, collection=Vector)
    self.assertIn("requires a set backend - one claiming Set", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      Multimap("neg_mm_col", "int", "int", set=AVLSet, collection=ChainedHashMap)
    self.assertIn("requires a collection backend - one claiming Insertable", str(ctx.exception))

    # Multimap rejects an Insertable collection that is NOT Traversable (e.g. PriorityQueue)
    with self.assertRaises(TraitError) as ctx:
      Multimap("neg_mm_pq", "int", "int", set=AVLSet, collection=PriorityQueue)
    self.assertIn("requires a collection backend - one claiming Traversable; got Queue", str(ctx.exception))

  def test_map_payload_freedom(self):
    opaque = OpaqueType("payload_opaque_t")
    # All maps should successfully instantiate with unhashable, non-comparable values
    chm = ChainedHashMap("test_chm_opaque", opaque, "int")
    tm = TreeMap("test_tm_opaque", opaque, "int", AVLSet)
    bm = BTreeMap("test_bm_opaque", opaque, "int")
    fm = FlatMap("test_fm_opaque", opaque, "int")
    fmm = FlatMultimap("test_fmm_opaque", opaque, "int")

    for m in (chm, tm, bm, fm, fmm):
      stream = []
      m.render_declarations(stream, True)
      m.render_definitions(stream, False)
      rendered = "".join(stream)
      self.assertTrue(len(rendered) > 0)

  def test_sequences_with_opaque_elements(self):
    opaque = OpaqueType("seq_opaque_t")
    vec = Vector("test_vec_opaque", opaque)
    lst = List("test_list_opaque", opaque)
    deq = Deque("test_deq_opaque", opaque)
    arr = Array("test_arr_opaque", opaque, 5)
    tv = TieredVector("test_tv_opaque", opaque)
    cb = DynamicCircularBuffer("test_cb_opaque", opaque)
    fcb = StaticCircularBuffer("test_fcb_opaque", opaque, 8)

    self.assertFalse(vec.comparable)
    self.assertFalse(vec.hashable)
    self.assertFalse(vec.equal.active)
    self.assertFalse(vec.hash.active)

    self.assertFalse(arr.comparable)
    self.assertFalse(arr.hashable)
    self.assertFalse(arr.equal.active)
    self.assertFalse(arr.hash.active)

    for c in (vec, lst, deq, arr, tv, cb, fcb):
      stream = []
      c.render_declarations(stream, True)
      c.render_definitions(stream, False)
      rendered = "".join(stream)
      self.assertTrue(len(rendered) > 0)

  def test_type_algebra(self):
    # IntersectionType creation and composition
    contract = Set & Ordered
    self.assertIsInstance(contract, IntersectionType)
    self.assertEqual(contract.__args__, (Set, Ordered))

    # Chaining intersections
    chained = Set & Ordered & Insertable
    self.assertEqual(chained.__args__, (Set, Ordered, Insertable))

    # Union with intersection
    union_contract = (Set & Ordered) | Mapping
    self.assertTrue(satisfies(AVLSet, union_contract))
    self.assertTrue(satisfies(FlatMap, union_contract))
    self.assertFalse(satisfies(Vector, union_contract))

    # Trait protocols
    self.assertTrue(satisfies("int", Comparable | Orderable))
    self.assertTrue(satisfies("int", Comparable & Orderable))
    self.assertTrue(satisfies("int", Hashable))

    co = ComparableOnlyType()
    self.assertTrue(satisfies(co, Comparable))
    self.assertFalse(satisfies(co, Orderable))
    self.assertTrue(satisfies(co, Comparable | Orderable))
    self.assertFalse(satisfies(co, Comparable & Orderable))

    op = OpaqueType()
    self.assertFalse(satisfies(op, Comparable))
    self.assertFalse(satisfies(op, Orderable))
    self.assertFalse(satisfies(op, Hashable))

    # Container satisfying IntersectionType
    self.assertTrue(satisfies(AVLSet, Set & Ordered))
    self.assertFalse(satisfies(ChainedHashSet, Set & Ordered))
    self.assertTrue(satisfies(ChainedHashSet, Set & Hashed))
    self.assertFalse(satisfies(FlatMap, Set & Ordered))
    self.assertTrue(satisfies(FlatMap, Mapping & Ordered))

  def test_fluent_require(self):
    inq = MockInquirer("fluent_test", "Tester")

    # Target-oriented require on classes
    self.assertIs(AVLSet.require(Set & Ordered, inq), AVLSet)
    self.assertIs(FlatMap.require(Mapping & Ordered, inq), FlatMap)
    self.assertIs(ChainedHashMap.require(Mapping & Hashed, inq), ChainedHashMap)

    with self.assertRaises(TraitError) as ctx:
      ChainedHashMap.require(Ordered, inq)
    self.assertIn("requires an ordered component", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      Vector.require(Set & Ordered, inq, "set backend")
    self.assertIn("requires a set backend - one claiming Set", str(ctx.exception))

    # Target-oriented require on instances
    vec = Vector("fluent_vec", "int")
    self.assertIs(vec.require(Insertable, inq), vec)
    self.assertIs(vec.element.require(Comparable, inq), vec.element)
    self.assertIs(vec.element.require(Orderable, inq), vec.element)

  def test_paradigm_b_factories(self):
    # FlatMap Paradigm B factory
    fm = FlatMap("fm_b", "int", "int")
    s_default = fm._make_set()
    self.assertIsInstance(s_default, FlatSet)
    s_avl = fm._make_set(backend=AVLSet)
    self.assertIsInstance(s_avl, AVLSet)

    with self.assertRaises(TraitError) as ctx:
      fm._make_set(backend=ChainedHashSet)
    self.assertIn("requires an ordered set backend", str(ctx.exception))

    with self.assertRaises(TraitError) as ctx:
      fm._make_set(backend=Vector)
    self.assertIn("requires a set backend - one claiming Set", str(ctx.exception))

    # Queue Paradigm B factory
    q = Queue("q_b", "int")
    d_default = q._make_deque()
    self.assertIsInstance(d_default, Deque)

    with self.assertRaises(TraitError) as ctx:
      q._make_deque(backend=AVLSet)
    self.assertIn("requires a backend - one claiming Sequential", str(ctx.exception))

    # Stack Paradigm B factory
    stk = Stack("stk_b", "int")
    l_default = stk._make_list()
    self.assertIsInstance(l_default, List)

    with self.assertRaises(TraitError) as ctx:
      stk._make_list(backend=AVLSet)
    self.assertIn("requires a backend - one claiming Sequential", str(ctx.exception))


# Run tests when imported or executed directly
suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestTraits)
runner = unittest.TextTestRunner()
result = runner.run(suite)
assert result.wasSuccessful(), f"Trait tests failed: {result.errors} {result.failures}"

if __name__ == "__main__":
  unittest.main()
