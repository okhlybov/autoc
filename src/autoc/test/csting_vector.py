from autoc.test import *
from autoc.vector import Vector
from autoc.string import String as CString


x = Type(type := Vector("cstring_vector", CString("cstring")))

t = type.variable("t")


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

x.unit(f"{type.hash}(): hash empty vector", f"""
  TEST_TRUE( {type.empty(t)} );
  {type.hash(t)};
""")


x.setup(f"""
  {t.definition};
  {type.create_size(t, 10)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.empty}(): test !empty vector", f"""
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 10 );
""")

x.unit(f"{type.hash}(): hash !empty default initialized vector", f"""
  TEST_FALSE( {type.empty(t)} );
  {type.hash(t)};
""")

x.unit(f"{type.hash}(): set element of vector", f"""
  TEST_FALSE( {type.empty(t)} );
  {type.set(t, 0, '"Zzz"')};
""")

x.unit(f"{type.hash}(): contains string", f"""
  TEST_FALSE( {type.empty(t)} );
  {type.set(t, 0, '"Abc"')};
  {type.set(t, 3, '"abC"')};
  TEST_TRUE( {type.contains(t, '"abC"')});
  TEST_FALSE( {type.contains(t, '"abc"')});
""")