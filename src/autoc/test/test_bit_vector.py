from autoc.test import *
from autoc.bit_vector import Vector

x = Type(type := Vector("test_bitvector"))

t = type.variable("t")
t1 = type.variable("t1")
t2 = type.variable("t2")


x.setup(f"""
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")


x.unit(f"{type.empty}(): new bitvector is empty", f"""
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.none(t)} );
  TEST_FALSE( {type.any(t)} );
  TEST_EQUAL( {type.count(t)}, 0 );
""")

x.unit(f"{type.push}(): push bits to bitvector", f"""
  {type.push(t, 1)};
  {type.push(t, 0)};
  {type.push(t, 1)};
  TEST_FALSE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 3 );
  TEST_EQUAL( {type.get(t, 0)}, 1 );
  TEST_EQUAL( {type.get(t, 1)}, 0 );
  TEST_EQUAL( {type.get(t, 2)}, 1 );
  TEST_EQUAL( {type.count(t)}, 2 );
  TEST_TRUE( {type.any(t)} );
  TEST_FALSE( {type.all(t)} );
""")

x.unit(f"{type.pop}(): pop bits from bitvector", f"""
  {type.push(t, 1)};
  {type.push(t, 0)};
  TEST_EQUAL( {type.size(t)}, 2 );
  TEST_EQUAL( {type.pop(t)}, 0 );
  TEST_EQUAL( {type.size(t)}, 1 );
  TEST_EQUAL( {type.pop(t)}, 1 );
  TEST_EQUAL( {type.size(t)}, 0 );
  TEST_TRUE( {type.empty(t)} );
""")

x.unit(f"{type.set}()/get()/flip(): bit modifications", f"""
  size_t i;
  {type.resize(t, 70)};
  TEST_EQUAL( {type.size(t)}, 70 );
  TEST_TRUE( {type.none(t)} );

  {type.set(t, 0, 1)};
  {type.set(t, 63, 1)};
  {type.set(t, 64, 1)};
  {type.set(t, 69, 1)};

  TEST_EQUAL( {type.get(t, 0)}, 1 );
  TEST_EQUAL( {type.get(t, 63)}, 1 );
  TEST_EQUAL( {type.get(t, 64)}, 1 );
  TEST_EQUAL( {type.get(t, 69)}, 1 );
  TEST_EQUAL( {type.get(t, 1)}, 0 );
  TEST_EQUAL( {type.get(t, 65)}, 0 );
  TEST_EQUAL( {type.count(t)}, 4 );

  {type.clear_bit(t, 63)};
  TEST_EQUAL( {type.get(t, 63)}, 0 );
  TEST_EQUAL( {type.count(t)}, 3 );

  {type.flip_bit(t, 0)};
  TEST_EQUAL( {type.get(t, 0)}, 0 );
  {type.flip_bit(t, 0)};
  TEST_EQUAL( {type.get(t, 0)}, 1 );
""")

x.unit(f"{type.set_all}()/{type.reset_all}(): bulk bit operations", f"""
  {type.resize(t, 100)};
  {type.set_all(t)};
  TEST_EQUAL( {type.count(t)}, 100 );
  TEST_TRUE( {type.all(t)} );
  TEST_TRUE( {type.any(t)} );
  TEST_FALSE( {type.none(t)} );

  {type.reset_all(t)};
  TEST_EQUAL( {type.count(t)}, 0 );
  TEST_FALSE( {type.all(t)} );
  TEST_FALSE( {type.any(t)} );
  TEST_TRUE( {type.none(t)} );

  {type.flip(t)};
  TEST_EQUAL( {type.count(t)}, 100 );
  TEST_TRUE( {type.all(t)} );
""")

x.unit(f"{type.find_first}(): search for set bits", f"""
  {type.resize(t, 80)};
  TEST_EQUAL( {type.find_first(t)}, 80 );

  {type.set(t, 65, 1)};
  TEST_EQUAL( {type.find_first(t)}, 65 );

  {type.set(t, 10, 1)};
  TEST_EQUAL( {type.find_first(t)}, 10 );

  {type.set(t, 0, 1)};
  TEST_EQUAL( {type.find_first(t)}, 0 );
""")

x.unit(f"{type.copy}()/{type.move}(): value semantics", f"""
  {t1.definition};
  {t2.definition};
  {type.create(t1)};
  {type.create(t2)};

  {type.push(t1, 1)};
  {type.push(t1, 0)};
  {type.push(t1, 1)};

  {type.copy(t2, t1)};
  TEST_EQUAL( {type.size(t2)}, 3 );
  TEST_TRUE( {type.equal(t1, t2)} );

  {type.destroy(t2)};
  {type.create(t2)};
  {type.move(t2, t1)};
  TEST_EQUAL( {type.size(t2)}, 3 );
  TEST_EQUAL( {type.size(t1)}, 0 );
  TEST_TRUE( {type.empty(t1)} );

  {type.destroy(t1)};
  {type.destroy(t2)};
""")

x.unit(f"{type.assign_union}(): bitwise union", f"""
  {t1.definition};
  {t2.definition};
  {type.create(t1)};
  {type.create(t2)};

  {type.resize(t1, 10)};
  {type.resize(t2, 10)};
  {type.set(t1, 1, 1)};
  {type.set(t1, 3, 1)};
  {type.set(t2, 3, 1)};
  {type.set(t2, 5, 1)};

  {type.assign_union(t1, t2)};
  TEST_EQUAL( {type.get(t1, 1)}, 1 );
  TEST_EQUAL( {type.get(t1, 3)}, 1 );
  TEST_EQUAL( {type.get(t1, 5)}, 1 );
  TEST_EQUAL( {type.get(t1, 0)}, 0 );
  TEST_EQUAL( {type.count(t1)}, 3 );

  {type.destroy(t1)};
  {type.destroy(t2)};
""")

x.unit(f"{type.assign_intersection}(): bitwise intersection", f"""
  {t1.definition};
  {t2.definition};
  {type.create(t1)};
  {type.create(t2)};

  {type.resize(t1, 10)};
  {type.resize(t2, 10)};
  {type.set(t1, 1, 1)};
  {type.set(t1, 3, 1)};
  {type.set(t2, 3, 1)};
  {type.set(t2, 5, 1)};

  {type.assign_intersection(t1, t2)};
  TEST_EQUAL( {type.get(t1, 1)}, 0 );
  TEST_EQUAL( {type.get(t1, 3)}, 1 );
  TEST_EQUAL( {type.get(t1, 5)}, 0 );
  TEST_EQUAL( {type.count(t1)}, 1 );

  {type.destroy(t1)};
  {type.destroy(t2)};
""")

x.unit(f"{type.is_subset}(): subset predicate", f"""
  {t1.definition};
  {t2.definition};
  {type.create(t1)};
  {type.create(t2)};

  {type.resize(t1, 10)};
  {type.resize(t2, 10)};
  TEST_TRUE( {type.is_subset(t1, t2)} );

  {type.set(t1, 2, 1)};
  TEST_FALSE( {type.is_subset(t1, t2)} );

  {type.set(t2, 2, 1)};
  {type.set(t2, 4, 1)};
  TEST_TRUE( {type.is_subset(t1, t2)} );

  {type.destroy(t1)};
  {type.destroy(t2)};
""")
