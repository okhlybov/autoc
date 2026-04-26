from autoc.test import *
from autoc.intrusive_hash_set import Set
from autoc.test.cstring import cstring, s


xs = {
  "is_empty": lambda element: f"{element} == (char*)(unsigned long)0  /* EMPTY? */",
  "mark_empty": lambda element: f"{element} = (char*)(unsigned long)0  /* EMPTY */",
  "is_deleted": lambda element: f"{element} == (char*)(unsigned long)1  /* DELETED? */",
  "mark_deleted": lambda element: f"{element} = (char*)(unsigned long)1  /* DELETED */",
}

x = Type(type := Set("intrusive_cstring_hash_set", cstring, **xs))

t = type.variable("t")

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
  TEST_TRUE( {type.put(t, s("hello"))} );
""")

x.unit(f"{type.create_size}(): create empty set with zero size", f"""
  {type.create_size(t, 0)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")

x.unit(f"{type.put}(): put new entry", f"""
  {type.create_size(t, 0)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, s("hello"))} );
  TEST_EQUAL( {type.size(t)}, 1 );
""")

x.unit(f"{type.put}(): put !new entry", f"""
  {type.create_size(t, 0)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, s("hello"))} );
  TEST_FALSE( {type.put(t, s("hello"))} );
  TEST_EQUAL( {type.size(t)}, 1 );
""")

x.unit(f"{type.resize}(): shrink empty set", f"""
  {type.create_size(t, 1024+11)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  {type.resize(t, 0)};
""")

x.unit(f"{type.remove}(): remove !existing element", f"""
  {type.create(t)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_FALSE( {type.remove(t, s("hello"))} );
""")

x.unit(f"{type.remove}(): remove existing element", f"""
  {type.create(t)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.put(t, s("hello"))} );
  TEST_TRUE( {type.remove(t, s("hello"))} );
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")