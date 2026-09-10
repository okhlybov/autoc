from autoc.test import *
from autoc.vector import Vector
from autoc.test.callback import unary, helpers

x = Type(type := Vector("callback_vector", unary), dependencies=[helpers])

t = type.variable("t")
t2 = type.variable("t2")

v = unary.variable("v")


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

x.unit(f"{type.create_size}(): default initializes elements with null pointers", f"""
  {type.create_size(t, 2)};
  TEST_EQUAL( {type.size(t)}, 2 );
  TEST_TRUE( *{type.view(t, 0)} == NULL );
  TEST_TRUE( *{type.view(t, 1)} == NULL );
""")

x.unit(f"{type.set}(): set element then call through the view", f"""
  {type.create_size(t, 2)};
  {type.set(t, 0, "callback_double")};
  TEST_EQUAL( {unary.call(type.view(t, 0), 21)}, 42 );
""")

x.unit(f"{type.get}(): get element then call the returned value", f"""
  {type.create_size(t, 2)};
  {type.set(t, 0, "callback_double")};
  TEST_EQUAL( {unary.call(type.get(t, 0), 4)}, 8 );
""")

x.unit(f"{unary}: call through a variable of the callback type", f"""
  {v.definition};
  {v} = callback_negate;
  TEST_EQUAL( {v(7)}, -7 );
  {v} = callback_double;
  TEST_EQUAL( {v(7)}, 14 );
""")

x.unit(f"{type.contains}(): contained element", f"""
  {type.create_size(t, 2)};
  {type.set(t, 0, "callback_double")};
  TEST_TRUE( {type.contains(t, "callback_double")} );
  TEST_FALSE( {type.contains(t, "callback_negate")} );
""")


x.setup(f"""
  {t.definition};
  {t2.definition};
  {type.create(t)};
  {type.create(t2)};
""")
x.cleanup(f"""
  {type.destroy(t)};
  {type.destroy(t2)};
""")

x.unit(f"{type.copy}(): copy vector of callbacks", f"""
  {type.create_size(t, 2)};
  {type.set(t, 0, "callback_double")};
  {type.set(t, 1, "callback_negate")};
  {type.copy(t2, t)};
  TEST_TRUE( {type.equal(t, t2)} );
  TEST_EQUAL( {type.hash(t)}, {type.hash(t2)} );
  TEST_EQUAL( {unary.call(type.view(t2, 0), 3)}, 6 );
  TEST_EQUAL( {unary.call(type.view(t2, 1), 3)}, -3 );
""")

x.unit(f"{type.set}(): overwrite element", f"""
  {type.create_size(t, 2)};
  {type.set(t, 0, "callback_double")};
  {type.set(t, 0, "callback_negate")};
  TEST_TRUE( {type.contains(t, "callback_negate")} );
  TEST_FALSE( {type.contains(t, "callback_double")} );
""")
