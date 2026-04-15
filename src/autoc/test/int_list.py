from autoc.test import *
import autoc.list

x = Type(type := autoc.list.List("int_list", "int"))

t = type.variable("t")


x.setup(f"""
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.empty}(): test empty list", f"""
  TEST_TRUE( {type.empty(t)} );
""")

x.unit(f"!{type.empty}(): test !empty list", f"""
  {type.push_front(t, 0)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.front(t)}, 0 );
""")

x.unit(f"{type.front}(): front peek from !empty list", f"""
  {type.push_front(t, 0)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
  TEST_EQUAL( {type.front(t)}, 0 );
""")

x.unit(f"{type.front_view}(): front view from !empty list", f"""
  {type.push_front(t, 0)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
  TEST_EQUAL( *{type.front_view(t)}, 0 );
""")

x.unit(f"{type.push_front}(): push to empty list", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  {type.push_front(t, 0)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
""")


x.setup(f"""
  {t.definition};
  {type.create(t)};
  {type.push_front(t, 0)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.push_front}(): push to !empty list", f"""
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
  {type.push_front(t, 1)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 2 );
""")

x.unit(f"{type.pop_front}(): pop from !empty list", f"""
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
  TEST_EQUAL( {type.front(t)}, 0 );
  TEST_EQUAL( {type.pop_front(t)}, 0 );
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
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

x.unit(f"{range}(): traverse empty list", f"""
  for({r} = {range.new(t)}; !{range.empty(r)}; {range.move_front(r)}) {{
    TEST_FALSE( {range.empty(r)} );
  }}
  TEST_TRUE( {range.empty(r)} );
""")

x.unit(f"!{range}(): traverse !empty list", f"""
  {type.push_front(t, -1)};
  for({r} = {range.new(t)}; !{range.empty(r)}; {range.move_front(r)}) {{
    TEST_FALSE( {range.empty(r)} );
    TEST_EQUAL( {range.front(r)}, -1 );
  }}
  TEST_TRUE( {range.empty(r)} );
""")