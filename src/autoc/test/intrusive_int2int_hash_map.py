from autoc.test import *
from autoc.intrusive_hash_map import Map

# Better to use index field for marking entries otherwise
# memory debuggers gonna complain about uninitialized access

xs = {
  "is_empty": lambda entry: f"{entry}.index == INT_MIN /* EMPTY? */",
  "mark_empty": lambda entry: f"{entry}.index = INT_MIN /* EMPTY */",
  "is_deleted": lambda entry: f"{entry}.index == INT_MAX /* DELETED? */",
  "mark_deleted": lambda entry: f"{entry}.index = INT_MAX /* DELETED */",
}

x = Type(type := Map("intrusive_int2int_hash_map", "int", "int", **xs))

t = type.variable("t")

x.setup(f"""
  {t.definition};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.create}(): create empty set with zero size", f"""
  {type.create(t)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")

x.unit(f"{type.create}(): put to empty map", f"""
  {type.create(t)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  {type.set(t, 0, 0)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
""")

x.unit(f"{type.create}(): put to !empty map", f"""
  {type.create(t)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  {type.set(t, 0, 0)};
  {type.set(t, 1, -1)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 2 );
""")