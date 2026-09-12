from autoc.test import *
from autoc.tiered_vector import TieredVector

# The small chunk shift exercises the multi chunk growth and the chunk table
# doubling without the large element counts

x = Type(type := TieredVector("int_tiered_vector", "int", chunk_shift=4))

t = type.variable("t")
t2 = type.variable("t2")

range = type.range
r = range.variable("r")


x.setup(f"""
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.empty}(): test empty vector", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")

x.unit(f"{type.push}(): push into empty vector", f"""
  {type.push(t, 42)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
  TEST_EQUAL( {type.get(t, 0)}, 42 );
""")

x.unit(f"{type.push}(): push across the chunk boundaries", f"""
  int i;
  for(i = 0; i < 100; ++i) {type.push(t, "i")};
  TEST_EQUAL( {type.size(t)}, 100 );
  for(i = 0; i < 100; ++i) TEST_EQUAL( {type.get(t, "i")}, i );
""")

x.unit(f"{type.pop}(): pop the last element", f"""
  {type.push(t, 7)};
  {type.push(t, 9)};
  TEST_EQUAL( {type.pop(t)}, 9 );
  TEST_EQUAL( {type.size(t)}, 1 );
  TEST_EQUAL( {type.get(t, 0)}, 7 );
""")


x.setup(f"""
  int i;
  {t.definition};
  {type.create_size(t, 40)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.create_size}(): default initialized elements", f"""
  TEST_EQUAL( {type.size(t)}, 40 );
  for(i = 0; i < 40; ++i) TEST_EQUAL( {type.get(t, "i")}, 0 );
""")

x.unit(f"{type.set}(): overwrite elements across chunks", f"""
  for(i = 0; i < 40; ++i) {type.set(t, "i", "40 - i")};
  for(i = 0; i < 40; ++i) TEST_EQUAL( {type.get(t, "i")}, 40 - i );
""")

x.unit(f"{type.hash}(): hash !empty vector", f"""
  {type.hash(t)};
""")


x.setup(f"""
  int i;
  {t.definition};
  {t2.definition};
  {type.create(t)};
  {type.create(t2)};
""")
x.cleanup(f"""
  {type.destroy(t)};
  {type.destroy(t2)};
""")

x.unit(f"{type.copy}(): copy across chunks", f"""
  for(i = 0; i < 40; ++i) {type.push(t, "i")};
  {type.copy(t2, t)};
  TEST_TRUE( {type.equal(t, t2)} );
  TEST_EQUAL( {type.hash(t)}, {type.hash(t2)} );
  TEST_EQUAL( {type.size(t2)}, 40 );
  TEST_EQUAL( {type.get(t2, 33)}, 33 );
""")

x.unit(f"{type.equal}(): compare !equal vectors", f"""
  {type.push(t, 1)};
  {type.push(t2, 2)};
  TEST_FALSE( {type.equal(t, t2)} );
""")


x.setup(f"""
  int i;
  {r.definition};
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{range}(): traverse empty vector", f"""
  for({r} = {range.new(t)}; !{range.empty(r)}; {range.move_front(r)}) {{
    TEST_FALSE( {range.empty(r)} );
  }}
  TEST_TRUE( {range.empty(r)} );
""")

x.unit(f"{range}(): traverse across chunks", f"""
  i = 0;
  for(i = 0; i < 50; ++i) {type.push(t, "i")};
  i = 0;
  for({r} = {range.new(t)}; !{range.empty(r)}; {range.move_front(r)}) {{
    TEST_EQUAL( {range.front(r)}, i );
    ++i;
  }}
  TEST_EQUAL( i, 50 );
""")
