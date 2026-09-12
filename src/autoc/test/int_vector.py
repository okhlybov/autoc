from autoc.test import *
from autoc.vector import Vector

x = Type(type := Vector("int_vector", "int"))

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
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.sort}(): sort empty vector", f"""
  {type.sort(t)};
  TEST_TRUE( {type.is_sorted(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")


x.setup(f"""
  int i;
  {t.definition};
  {type.create_size(t, 8)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.sort}(): sort descending vector", f"""
  for(i = 0; i < 8; ++i) {type.set(t, "i", "8 - i")};
  TEST_FALSE( {type.is_sorted(t)} );
  {type.sort(t)};
  TEST_TRUE( {type.is_sorted(t)} );
  for(i = 0; i < 8; ++i) TEST_EQUAL( {type.get(t, "i")}, i + 1 );
""")

x.unit(f"{type.sort}(): sort vector with duplicates", f"""
  int expected[] = {{1, 1, 2, 2, 3, 3, 4, 4}};
  {type.set(t, 0, 3)}; {type.set(t, 1, 1)}; {type.set(t, 2, 4)}; {type.set(t, 3, 1)};
  {type.set(t, 4, 3)}; {type.set(t, 5, 2)}; {type.set(t, 6, 4)}; {type.set(t, 7, 2)};
  {type.sort(t)};
  TEST_TRUE( {type.is_sorted(t)} );
  for(i = 0; i < 8; ++i) TEST_EQUAL( {type.get(t, "i")}, expected[i] );
""")

x.unit(f"{type.sort}(): sort all equal elements", f"""
  for(i = 0; i < 8; ++i) {type.set(t, "i", 7)};
  {type.sort(t)};
  TEST_TRUE( {type.is_sorted(t)} );
  TEST_EQUAL( {type.get(t, 3)}, 7 );
""")

x.unit(f"{type.sort}(): sort already sorted vector", f"""
  for(i = 0; i < 8; ++i) {type.set(t, "i", "i")};
  {type.sort(t)};
  TEST_TRUE( {type.is_sorted(t)} );
  for(i = 0; i < 8; ++i) TEST_EQUAL( {type.get(t, "i")}, i );
""")


x.setup(f"""
  int i;
  long long sum;
  {t.definition};
  {type.create_size(t, 64)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.sort}(): sort permutation of 64 elements", f"""
  for(i = 0; i < 64; ++i) {type.set(t, "i", "(i*37 + 11)%64")};
  sum = 0;
  for(i = 0; i < 64; ++i) sum += {type.get(t, "i")};
  TEST_EQUAL( sum, 2016 );
  {type.sort(t)};
  TEST_TRUE( {type.is_sorted(t)} );
  TEST_EQUAL( {type.get(t, 0)}, 0 );
  TEST_EQUAL( {type.get(t, 63)}, 63 );
  sum = 0;
  for(i = 0; i < 64; ++i) sum += {type.get(t, "i")};
  TEST_EQUAL( sum, 2016 );
""")


x.setup(f"""
  int i;
  {t.definition};
  {type.create_size(t, 8)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.reverse}(): reverse descending vector into ascending", f"""
  for(i = 0; i < 8; ++i) {type.set(t, "i", "8 - i")};
  {type.reverse(t)};
  TEST_TRUE( {type.is_sorted(t)} );
  for(i = 0; i < 8; ++i) TEST_EQUAL( {type.get(t, "i")}, i + 1 );
""")

x.unit(f"{type.reverse}(): reverse twice restores the original", f"""
  for(i = 0; i < 8; ++i) {type.set(t, "i", "i*3 % 8")};
  {type.reverse(t)};
  {type.reverse(t)};
  for(i = 0; i < 8; ++i) TEST_EQUAL( {type.get(t, "i")}, i*3 % 8 );
""")

x.unit(f"{type.reverse}(): reverse empty and single element vectors", f"""
  {type.destroy(t)};
  {type.create(t)};
  {type.reverse(t)};
  TEST_TRUE( {type.empty(t)} );
  {type.create_size(t, 1)};
  {type.set(t, 0, 5)};
  {type.reverse(t)};
  TEST_EQUAL( {type.get(t, 0)}, 5 );
""")
