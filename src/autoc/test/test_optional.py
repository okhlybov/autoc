from autoc.test import *
from autoc.vector import Vector
from autoc.array import Array
from autoc.tiered_vector import TieredVector
from autoc.chained_hash_set import Set as ChainedHashSet
from autoc.chained_hash_map import Map as ChainedHashMap
from autoc.intrusive_hash_map import Map as IntrusiveHashMap
from autoc.treap_set import Set as TreapSet
from autoc.treap_map import Map as TreapMap
from autoc.bitset import BitSet
from autoc.string import String
from autoc.string_buffer import StringBuffer


# 1. Verify sorting_operations on Vector, TieredVector, and Array
v_nosort = Vector("v_nosort", "int", sorting_operations=False)
assert not v_nosort.sort.active
assert not v_nosort.reverse.active
assert not v_nosort.sorted.active
assert not v_nosort.binary_search.active
assert not v_nosort.lower_bound.active
assert not v_nosort.upper_bound.active
assert v_nosort.push.active
assert v_nosort.pop.active
assert v_nosort.size.active

v_sort = Vector("v_sort", "int")
assert v_sort.sort.active
assert v_sort.reverse.active
assert v_sort.sorted.active
assert v_sort.binary_search.active

tv_nosort = TieredVector("tv_nosort", "int", sorting_operations=False)
assert not tv_nosort.sort.active
assert not tv_nosort.reverse.active
assert not tv_nosort.sorted.active
assert not tv_nosort.binary_search.active
assert tv_nosort.push.active

arr_nosort = Array("arr_nosort", "int", 8, sorting_operations=False)
assert not arr_nosort.sort.active
assert not arr_nosort.reverse.active
assert not arr_nosort.sorted.active
assert not arr_nosort.binary_search.active
assert arr_nosort.get.active
assert arr_nosort.set.active

arr_sort = Array("arr_sort", "int", 8)
assert arr_sort.sort.active
assert arr_sort.reverse.active
assert arr_sort.sorted.active


# 2. Verify algebraic_operations on ChainedHashSet, TreapSet, and BitSet
s_noalg = ChainedHashSet("s_noalg", "int", algebraic_operations=False)
assert not s_noalg.union.active
assert not s_noalg.difference.active
assert not s_noalg.intersection.active
assert not s_noalg.symmetric_difference.active
assert not s_noalg.is_subset.active
assert not s_noalg.is_superset.active
assert s_noalg.put.active
assert s_noalg.remove.active
assert s_noalg.contains.active

s_alg = ChainedHashSet("s_alg", "int")
assert s_alg.union.active
assert s_alg.is_subset.active

ts_noalg = TreapSet("ts_noalg", "int", algebraic_operations=False)
assert not ts_noalg.union.active
assert not ts_noalg.difference.active
assert not ts_noalg.intersection.active
assert not ts_noalg.symmetric_difference.active
assert ts_noalg.put.active
assert ts_noalg.contains.active

bs_noalg = BitSet("bs_noalg", 32, algebraic_operations=False)
assert not bs_noalg.assign_union.active
assert not bs_noalg.assign_intersection.active
assert not bs_noalg.assign_difference.active
assert not bs_noalg.assign_symmetric_difference.active
assert not bs_noalg.is_subset.active
assert bs_noalg.test.active
assert bs_noalg.set.active
assert bs_noalg.count.active

bs_alg = BitSet("bs_alg", 32)
assert bs_alg.assign_union.active
assert bs_alg.is_subset.active


# 3. Verify formatting_operations on String and StringBuffer
str_noformat = String("str_noformat", formatting_operations=False)
assert not str_noformat.format.active
assert not str_noformat.format_args.active
assert str_noformat.size.active
assert str_noformat.new.active

str_format = String("str_format")
assert str_format.format.active
assert str_format.format_args.active

sbuf_noformat = StringBuffer("sbuf_noformat", formatting_operations=False)
assert not sbuf_noformat.push_format.active
assert not sbuf_noformat.push_format_args.active
assert not sbuf_noformat.push_double.active
assert not sbuf_noformat.push_long_double.active
assert sbuf_noformat.push.active
assert sbuf_noformat.push_slice.active
assert sbuf_noformat.push_char.active
assert sbuf_noformat.push_int.active

sbuf_format = StringBuffer("sbuf_format")
assert sbuf_format.push_format.active
assert sbuf_format.push_double.active


# 4. Verify enclosing consumers explicitly set disabled features
cmap = ChainedHashMap("cmap_test", "int", "int")
assert cmap._set.algebraic_operations is False
assert not cmap._set.union.active
assert not cmap._set.is_subset.active

tmap = TreapMap("tmap_test", "int", "int")
assert tmap._set.algebraic_operations is False
assert not tmap._set.union.active

sbuf = StringBuffer("sbuf_test")
assert sbuf._string.formatting_operations is False
assert not sbuf._string.format.active
assert sbuf._chunks.sorting_operations is False
assert not sbuf._chunks.sort.active


# 5. C execution tests for types generated with disabled features
xv = Type(type_v := Vector("opt_int_vector", "int", sorting_operations=False))
tv = type_v.variable("tv")
xv.setup(f"""
  {tv.definition};
  {type_v.create(tv)};
""")
xv.cleanup(f"""
  {type_v.destroy(tv)};
""")
xv.unit(f"{type_v}: operations work when sorting is disabled", f"""
  {type_v.push(tv, 10)};
  {type_v.push(tv, 20)};
  {type_v.push(tv, 30)};
  TEST_EQUAL( {type_v.size(tv)}, 3 );
  TEST_EQUAL( {type_v.get(tv, 0)}, 10 );
  TEST_EQUAL( {type_v.get(tv, 1)}, 20 );
  TEST_EQUAL( {type_v.get(tv, 2)}, 30 );
  TEST_EQUAL( {type_v.pop(tv)}, 30 );
  TEST_EQUAL( {type_v.size(tv)}, 2 );
""")

xbs = Type(type_bs := BitSet("opt_bitset", 16, algebraic_operations=False))
tbs = type_bs.variable("tbs")
xbs.setup(f"""
  {tbs.definition};
  {type_bs.create(tbs)};
""")
xbs.unit(f"{type_bs}: bitset operations work when algebra is disabled", f"""
  {type_bs.set(tbs, 3)};
  {type_bs.set(tbs, 7)};
  TEST_TRUE( {type_bs.test(tbs, 3)} );
  TEST_TRUE( {type_bs.test(tbs, 7)} );
  TEST_FALSE( {type_bs.test(tbs, 5)} );
  TEST_EQUAL( {type_bs.count(tbs)}, 2 );
  {type_bs.clear(tbs, 3)};
  TEST_FALSE( {type_bs.test(tbs, 3)} );
  TEST_EQUAL( {type_bs.count(tbs)}, 1 );
""")

xsb = Type(type_sb := StringBuffer("opt_string_buffer", formatting_operations=False))
tsb = type_sb.variable("tsb")
xsb.setup(f"""
  {tsb.definition};
  {type_sb.create(tsb)};
""")
xsb.cleanup(f"""
  {type_sb.destroy(tsb)};
""")
xsb.unit(f"{type_sb}: string buffer works when formatting is disabled", f"""
  {type_sb.push(tsb, '"Hello "')};
  {type_sb.push_char(tsb, "'W'")};
  {type_sb.push(tsb, '"orld"')};
  {type_sb.push_int(tsb, 42)};
  TEST_EQUAL_CHARS( {type_sb.view(tsb)}, "Hello World42" );
""")


# 6. Verify optional_group metadata and documentation notes on methods
assert v_sort.sort.optional_group == "sorting_operations"
assert v_sort.reverse.optional_group == "sorting_operations"
assert v_sort.sorted.optional_group == "sorting_operations"
assert v_sort.binary_search.optional_group == "sorting_operations"
assert v_sort.lower_bound.optional_group == "sorting_operations"
assert v_sort.upper_bound.optional_group == "sorting_operations"
assert v_sort.push.optional_group is None

assert s_alg.union.optional_group == "algebraic_operations"
assert s_alg.difference.optional_group == "algebraic_operations"
assert s_alg.intersection.optional_group == "algebraic_operations"
assert s_alg.symmetric_difference.optional_group == "algebraic_operations"
assert s_alg.is_subset.optional_group == "algebraic_operations"
assert s_alg.is_superset.optional_group == "algebraic_operations"
assert s_alg.put.optional_group is None

assert bs_alg.assign_union.optional_group == "algebraic_operations"
assert bs_alg.assign_intersection.optional_group == "algebraic_operations"
assert bs_alg.assign_difference.optional_group == "algebraic_operations"
assert bs_alg.assign_symmetric_difference.optional_group == "algebraic_operations"
assert bs_alg.is_subset.optional_group == "algebraic_operations"
assert bs_alg.test.optional_group is None

assert str_format.format.optional_group == "formatting_operations"
assert str_format.format_args.optional_group == "formatting_operations"

assert sbuf_format.push_format.optional_group == "formatting_operations"
assert sbuf_format.push_format_args.optional_group == "formatting_operations"
assert sbuf_format.push_double.optional_group == "formatting_operations"
assert sbuf_format.push_long_double.optional_group == "formatting_operations"
assert sbuf_format.push.optional_group is None

# Verify documentation comment rendering contains optional group note
stream = []
v_sort.sort._render_documentation(stream, True)
rendered_doc = "".join(stream)
assert "_An optional operation belonging to the Sortable function group._" in rendered_doc

stream = []
s_alg.union._render_documentation(stream, True)
rendered_doc = "".join(stream)
assert "_An optional operation belonging to the AlgebraicSet function group._" in rendered_doc

stream = []
sbuf_format.push_format._render_documentation(stream, True)
rendered_doc = "".join(stream)
assert "_An optional operation belonging to the Formatting function group._" in rendered_doc


# 7. Verify function-level references and dependencies of formatting and wrapper methods
import autoc.std as std

# String.format references format_args (no ordering dependency on format_args, depends only on stdarg.h)
assert str_format.format_args in str_format.format.references
assert str_format.format_args not in str_format.format.dependencies
assert std.stdarg_h in str_format.format.dependencies
assert std.stdio_h not in str_format.format.dependencies
assert std.stdio_h in str_format.format_args.dependencies

# StringBuffer.push_format references push_format_args (no ordering dependency, depends only on stdarg.h)
assert sbuf_format.push_format_args in sbuf_format.push_format.references
assert sbuf_format.push_format_args not in sbuf_format.push_format.dependencies
assert std.stdarg_h in sbuf_format.push_format.dependencies
assert std.stdio_h not in sbuf_format.push_format.dependencies
assert std.stdio_h in sbuf_format.push_format_args.dependencies

# StringBuffer.push_double / push_long_double reference push_format without header dependencies
assert sbuf_format.push_format in sbuf_format.push_double.references
assert sbuf_format.push_format not in sbuf_format.push_double.dependencies
assert std.stdio_h not in sbuf_format.push_double.dependencies
assert sbuf_format.push_format in sbuf_format.push_long_double.references
assert sbuf_format.push_format not in sbuf_format.push_long_double.dependencies
assert std.stdio_h not in sbuf_format.push_long_double.dependencies

# StringBuffer integer and slice wrappers use references
assert sbuf_format.push_slice in sbuf_format.push.references
assert sbuf_format.push_slice not in sbuf_format.push.dependencies
assert sbuf_format.push_ulong in sbuf_format.push_uint.references
assert sbuf_format.push_ulong not in sbuf_format.push_uint.dependencies
assert sbuf_format.push_long in sbuf_format.push_int.references
assert sbuf_format.push_long not in sbuf_format.push_int.dependencies
assert sbuf_format.push_slice in sbuf_format.push_ulong.references
assert sbuf_format.push_slice in sbuf_format.push_long.references
assert sbuf_format.view in sbuf_format.take.references
assert sbuf_format.view not in sbuf_format.take.dependencies

# Sortable wrappers use references
assert v_sort.sort_range in v_sort.sort.references
assert v_sort.sort_range not in v_sort.sort.dependencies
assert v_sort.sort_insertion in v_sort.sort_range.references
assert v_sort.sort_insertion not in v_sort.sort_range.dependencies
assert v_sort.lower_bound in v_sort.binary_search.references
assert v_sort.lower_bound not in v_sort.binary_search.dependencies

# Array wrappers use references
assert arr_sort.get in arr_sort.front.references
assert arr_sort.get not in arr_sort.front.dependencies
assert arr_sort.view in arr_sort.front_view.references
assert arr_sort.view not in arr_sort.front_view.dependencies
assert arr_sort.get in arr_sort.back.references
assert arr_sort.get not in arr_sort.back.dependencies
assert arr_sort.view in arr_sort.back_view.references
assert arr_sort.view not in arr_sort.back_view.dependencies

