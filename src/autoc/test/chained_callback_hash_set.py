from autoc.test import *
from autoc.chained_hash_set import Set
from autoc.test.callback import unary, helpers

x = Type(type := Set("chained_callback_hash_set", unary), dependencies=[helpers])

t = type.variable("t")


x.setup(f"""
  {t.definition};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.put}(): put callbacks into empty set", f"""
  {type.create(t)};
  TEST_TRUE( {type.empty(t)} );
  TEST_TRUE( {type.put(t, "callback_double")} );
  TEST_TRUE( {type.put(t, "callback_negate")} );
  TEST_EQUAL( {type.size(t)}, 2 );
""")

x.unit(f"{type.put}(): put the same callback twice", f"""
  {type.create(t)};
  TEST_TRUE( {type.put(t, "callback_double")} );
  TEST_FALSE( {type.put(t, "callback_double")} );
  TEST_EQUAL( {type.size(t)}, 1 );
""")

x.unit(f"{type.contains}(): contained callbacks", f"""
  {type.create(t)};
  {type.put(t, "callback_double")};
  TEST_TRUE( {type.contains(t, "callback_double")} );
  TEST_FALSE( {type.contains(t, "callback_negate")} );
""")

x.unit(f"{type.find_view}(): find and call the contained callback", f"""
  {type.create(t)};
  {type.put(t, "callback_double")};
  TEST_EQUAL( {unary.call(type.find_view(t, "callback_double"), 8)}, 16 );
  TEST_TRUE( {type.find_view(t, "callback_negate")} == NULL );
""")

x.unit(f"{type.remove}(): remove existing callback", f"""
  {type.create(t)};
  {type.put(t, "callback_double")};
  TEST_TRUE( {type.remove(t, "callback_double")} );
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")

x.unit(f"{type.remove}(): remove !existing callback", f"""
  {type.create(t)};
  {type.put(t, "callback_double")};
  TEST_FALSE( {type.remove(t, "callback_negate")} );
  TEST_EQUAL( {type.size(t)}, 1 );
""")


range = type.range
r = range.variable("r")

x.setup(f"""
  {r.definition};
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{range}(): traverse set of callbacks", f"""
  int seen = 0;
  {type.put(t, "callback_double")};
  {type.put(t, "callback_negate")};
  for({r} = {range.new(t)}; !{range.empty(r)}; {range.move_front(r)}) {{
    if({range.front(r)} == callback_double) seen |= 1;
    else if({range.front(r)} == callback_negate) seen |= 2;
  }}
  TEST_EQUAL( seen, 3 );
""")

x.unit(f"{range}(): call every callback while traversing", f"""
  int seen = 0;
  {type.put(t, "callback_double")};
  {type.put(t, "callback_negate")};
  for({r} = {range.new(t)}; !{range.empty(r)}; {range.move_front(r)}) {{
    int result = {unary.call(range.front_view(r), 5)};
    if(result == 10) seen |= 1;
    else if(result == -5) seen |= 2;
  }}
  TEST_EQUAL( seen, 3 );
""")
