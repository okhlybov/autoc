from autoc.core import *
from autoc.test import *
from autoc.intrusive_hash_set import Set


class IntrusiveSetInt(TypeProxy):
  def is_empty(self, element):
    return f"{element} == INT_MIN /* EMPTY? */"
  def mark_empty(self, element):
    return f"{element} = INT_MIN /* EMPTY */"
  def is_deleted(self, element):
    return f"{element} == INT_MAX /* DELETED? */"
  def mark_deleted(self, element):
    return f"{element} = INT_MAX /* DELETED */"


x = Type(type := Set("intrusive_int_set", IntrusiveSetInt("int")))

t = type.variable("t")
t1 = type.variable("t1")
t2 = type.variable("t2")

range = type.range
r = range.variable("r")


x.setup(f"""
  {t.definition};
  {r.definition};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.create_size}(): create empty set with preferred capacity", f"""
  {type.create_size(t, 1024+11)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, -1)} );
""")

x.unit(f"{type.create_size}(): create empty set with zero size", f"""
  {type.create_size(t, 0)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, -1)} );
""")


x.setup(f"""
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.empty}(): test empty set", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")

x.unit(f"{type.range}(): traverse empty set", f"""
  {r.definition};
  for({r} = {range.new(t)}; !{range.empty(r)}; {range.move_front(r)}) TEST_ASSERT(0);
""")

x.unit(f"{type.hash}(): hash of empty set", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  {type.hash(t)};
""")

x.unit(f"{type.copy}(): copy empty set", f"""
  {t1.definition};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  {type.copy(t1, t)};
  TEST_TRUE( {type.empty(t1)} );
  TEST_EQUAL( {type.size(t1)}, 0 );
  {type.destroy(t1)};
""")

x.unit(f"{type.contains}(): lookup in empty set", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_FALSE( {type.contains(t, -1)} );
""")

x.unit(f"{type.empty}(): test !empty set", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, -1)} );
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
""")

x.unit(f"{type.put}(): put to empty set", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, -1)} );
""")

x.unit(f"{type.contains}(): successful lookup in !empty set", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, -1)} );
  TEST_TRUE( {type.contains(t, -1)} );
""")

x.unit(f"{type.contains}(): failed lookup in !empty set", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, -1)} );
  TEST_FALSE( {type.contains(t, 1)} );
""")

x.unit(f"{type.put}(): put to empty set triggering storage expansion", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  for(int i = -1; i < 33; ++i) {{
    TEST_TRUE( {type.put(t, "i")} );
  }}
  TEST_EQUAL( {type.size(t)}, 34 );
""")

x.setup(f"""
  {t.definition};
  {type.create(t)};
  for(int i = -8; i < 8; ++i) {{
    TEST_TRUE( {type.put(t, "i")} );
  }}
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.hash}(): hash of !empty set", f"""
  TEST_FALSE( {type.empty(t)} );
  {type.hash(t)};
""")

x.unit(f"{type.range}(): traverse !empty set", f"""
  {r.definition};
  int i = 0;
  for({r} = {range.new(t)}; !{range.empty(r)}; {range.move_front(r)}) ++i;
  TEST_EQUAL( i, 16 );
""")

x.unit(f"{type.copy}(): copy !empty set", f"""
  {t1.definition};
  {type.copy(t1, t)};
  TEST_EQUAL( {type.size(t)}, {type.size(t1)} );
  {type.destroy(t1)};
""")

x.unit(f"{type.contains}(): contains all elements", f"""
  for(int i = -8; i < 8; ++i) {{
    TEST_TRUE( {type.contains(t, "i")} );
  }}
  TEST_FALSE( {type.contains(t, 88)} );
""")

x.setup(f"""
  {t1.definition};
  {t2.definition};
  {type.create(t1)};
  {type.create(t2)};
  for(int i = -8; i <= 8; ++i) {{
    TEST_TRUE( {type.put(t1, "+i")} );
    TEST_TRUE( {type.put(t2, "-i")} );
  }}
""")
x.cleanup(f"""
  {type.destroy(t1)};
  {type.destroy(t2)};
""")

x.unit(f"{type.hash}(): hashes of two equal !empty sets", f"""
  TEST_TRUE( {type.equal(t1, t2)} );
  TEST_EQUAL( {type.hash(t1)}, {type.hash(t2)} );
""")