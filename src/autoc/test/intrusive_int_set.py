from autoc.core import *
from autoc.test import *
from autoc.hash.intrusive_set import *


class IS(IntrusiveSet):
  
  def _test_empty(self, result, parameters, **kws):
    return Macro(result, parameters, lambda element: f"{element} == INT_MIN /* EMPTY? */")

  def _mark_empty(self, result, parameters, **kws):
    return Macro(result, parameters, lambda element: f"{element} = INT_MIN /* EMPTY */")

  def _test_deleted(self, result, parameters, **kws):
    return Macro(result, parameters, lambda element: f"{element} == INT_MAX /* DELETED? */")

  def _mark_deleted(self, result, parameters, **kws):
    return Macro(result, parameters, lambda element: f"{element} = INT_MAX /* DELETED */")

  
x = Type(type := IS("int_intrusive_set", "int"))

t = type.variable("t")


x.setup(f"""
  {t.definition};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.create_size}(): create empty set with preferred capacity", f"""
  {type.create_size(t, 1024*1024+11)};
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

