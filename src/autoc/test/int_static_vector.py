from autoc.test import *
from autoc.static_vector import StaticVector

x = Type(type := StaticVector("int_static_vector", "int", 4))

t = type.variable("t")
t1 = type.variable("t1")
t2 = type.variable("t2")
r = type.range.variable("r")


x.setup(f"""
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t) if type.destructible else ""}
""")

x.unit(f"{type.empty}(): test empty static vector", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_EQUAL( {type.capacity(t)}, 4 );
""")

x.unit(f"{type.hash}(): hash empty static vector", f"""
  {type.hash(t)};
""")

x.unit(f"{type.contains}(): !contained in empty static vector", f"""
  TEST_FALSE( {type.contains(t, 42)} );
""")

x.unit(f"{type.push}(): push to empty static vector", f"""
  {type.push(t, 10)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 1 );
  TEST_EQUAL( {type.get(t, 0)}, 10 );
  TEST_EQUAL( *{type.view(t, 0)}, 10 );
  TEST_EQUAL( {type.front(t)}, 10 );
  TEST_EQUAL( {type.back(t)}, 10 );
  TEST_EQUAL( *{type.front_view(t)}, 10 );
  TEST_EQUAL( *{type.back_view(t)}, 10 );
""")

x.unit(f"{type.push}(): push up to capacity", f"""
  {type.push(t, 10)};
  {type.push(t, 20)};
  {type.push(t, 30)};
  {type.push(t, 40)};
  TEST_EQUAL( {type.size(t)}, 4 );
  TEST_EQUAL( {type.get(t, 0)}, 10 );
  TEST_EQUAL( {type.get(t, 1)}, 20 );
  TEST_EQUAL( {type.get(t, 2)}, 30 );
  TEST_EQUAL( {type.get(t, 3)}, 40 );
  TEST_EQUAL( {type.front(t)}, 10 );
  TEST_EQUAL( {type.back(t)}, 40 );
""")

x.unit(f"{type.set}(): set element at index", f"""
  {type.push(t, 10)};
  {type.push(t, 20)};
  {type.set(t, 1, 99)};
  TEST_EQUAL( {type.get(t, 1)}, 99 );
  TEST_EQUAL( *{type.view(t, 1)}, 99 );
  TEST_EQUAL( {type.back(t)}, 99 );
""")

x.unit(f"{type.pop}(): pop elements in LIFO order down to empty", f"""
  {type.push(t, 10)};
  {type.push(t, 20)};
  {type.push(t, 30)};
  TEST_EQUAL( {type.pop(t)}, 30 );
  TEST_EQUAL( {type.size(t)}, 2 );
  TEST_EQUAL( {type.back(t)}, 20 );
  TEST_EQUAL( {type.pop(t)}, 20 );
  TEST_EQUAL( {type.size(t)}, 1 );
  TEST_EQUAL( {type.back(t)}, 10 );
  TEST_EQUAL( {type.pop(t)}, 10 );
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")

x.unit(f"{type.clear}(): clear static vector", f"""
  {type.push(t, 1)};
  {type.push(t, 2)};
  {type.push(t, 3)};
  TEST_EQUAL( {type.size(t)}, 3 );
  {type.clear(t)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")

x.unit(f"{type.contains}(): test contains for present and absent elements", f"""
  {type.push(t, 5)};
  {type.push(t, 15)};
  {type.push(t, 25)};
  TEST_TRUE( {type.contains(t, 5)} );
  TEST_TRUE( {type.contains(t, 15)} );
  TEST_TRUE( {type.contains(t, 25)} );
  TEST_FALSE( {type.contains(t, 35)} );
""")

x.unit(f"{type.range}(): iterate range forward and backward", f"""
  int sum = 0;
  {r.definition};
  {type.push(t, 1)};
  {type.push(t, 2)};
  {type.push(t, 3)};
  for({r} = {type.range.new(t)}; !{type.range.empty(r)}; {type.range.move_front(r)}) {{
    sum += {type.range.front(r)};
  }}
  TEST_EQUAL( sum, 6 );

  {r} = {type.range.new(t)};
  TEST_EQUAL( {type.range.size(r)}, 3 );
  TEST_EQUAL( {type.range.front(r)}, 1 );
  TEST_EQUAL( {type.range.back(r)}, 3 );
  TEST_EQUAL( {type.range.get(r, 1)}, 2 );
  TEST_EQUAL( *{type.range.view(r, 1)}, 2 );
  {type.range.move_back(r)};
  TEST_EQUAL( {type.range.size(r)}, 2 );
  TEST_EQUAL( {type.range.back(r)}, 2 );
""")


x.setup(f"""
  {t1.definition};
  {type.create(t1)};
  {t2.definition};
  {type.create(t2)};
""")
x.cleanup(f"""
  {type.destroy(t1) if type.destructible else ""}
  {type.destroy(t2) if type.destructible else ""}
""")

x.unit(f"{type.equal}(): compare empty and populated static vectors", f"""
  TEST_TRUE( {type.equal(t1, t2)} );
  {type.push(t1, 7)};
  TEST_FALSE( {type.equal(t1, t2)} );
  {type.push(t2, 7)};
  TEST_TRUE( {type.equal(t1, t2)} );
  {type.push(t1, 8)};
  {type.push(t2, 9)};
  TEST_FALSE( {type.equal(t1, t2)} );
""")

x.unit(f"{type.hash}(): hash equal static vectors", f"""
  {type.push(t1, 42)};
  {type.push(t1, 99)};
  {type.push(t2, 42)};
  {type.push(t2, 99)};
  TEST_EQUAL( {type.hash(t1)}, {type.hash(t2)} );
""")

x.unit(f"{type.copy}(): copy static vector", f"""
  {type.push(t1, 100)};
  {type.push(t1, 200)};
  {type.copy(t2, t1)};
  TEST_TRUE( {type.equal(t1, t2)} );
  TEST_EQUAL( {type.size(t2)}, 2 );
  TEST_EQUAL( {type.get(t2, 0)}, 100 );
  TEST_EQUAL( {type.get(t2, 1)}, 200 );
""")

x.unit(f"{type.move}(): move static vector", f"""
  {type.push(t1, 111)};
  {type.push(t1, 222)};
  {type.move(t2, t1)};
  TEST_TRUE( {type.empty(t1)} );
  TEST_EQUAL( {type.size(t2)}, 2 );
  TEST_EQUAL( {type.get(t2, 0)}, 111 );
  TEST_EQUAL( {type.get(t2, 1)}, 222 );
""")


x.setup(f"""
  {t.definition};
  {type.create_size(t, 3)};
""")
x.cleanup(f"""
  {type.destroy(t) if type.destructible else ""}
""")

x.unit(f"{type.create_size}(): create default-initialized static vector", f"""
  TEST_EQUAL( {type.size(t)}, 3 );
  TEST_EQUAL( {type.get(t, 0)}, 0 );
  TEST_EQUAL( {type.get(t, 1)}, 0 );
  TEST_EQUAL( {type.get(t, 2)}, 0 );
""")
