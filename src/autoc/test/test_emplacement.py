from autoc.test import *
from autoc.test.custom_composite import Type as CustomComposite
from autoc.vector import Vector
from autoc.list import List
from autoc.flat_map import Map as FlatMap
from autoc.chained_hash_set import Set as ChainedHashSet
from autoc.priority_queue import Queue as PriorityQueue

# 1. Vector of CustomComposite (custom create(target, value))
custom_elem = CustomComposite("custom_elem")
vec_type = Vector("custom_elem_vector", custom_elem)
x_vec = Type(vec_type, dependencies=[custom_elem])

vt = vec_type.variable("vt")
x_vec.setup(f"""
  {vt.definition};
  {vec_type.create(vt)};
""")
x_vec.cleanup(f"""
  {vec_type.destroy(vt)};
""")

x_vec.unit(f"{vec_type.emplace_back}(): emplace with constructor parameter forwarding", f"""
  {vec_type.emplace_back(vt, 42)};
  {vec_type.emplace_back(vt, 99)};
  TEST_EQUAL({vec_type.size(vt)}, 2);
  TEST_EQUAL(*{vec_type.get(vt, 0)}.value, 42);
  TEST_EQUAL(*{vec_type.get(vt, 1)}.value, 99);
""")


# 2. List of CustomComposite
list_type = List("custom_elem_list", custom_elem)
x_list = Type(list_type, dependencies=[custom_elem])

lt = list_type.variable("lt")
x_list.setup(f"""
  {lt.definition};
  {list_type.create(lt)};
""")
x_list.cleanup(f"""
  {list_type.destroy(lt)};
""")

x_list.unit(f"{list_type.emplace_front}(): emplace_front forwarding", f"""
  {list_type.emplace_front(lt, 100)};
  {list_type.emplace_front(lt, 200)};
  TEST_EQUAL({list_type.size(lt)}, 2);
  TEST_EQUAL(*{list_type.front_view(lt)}->value, 200);
""")


# 3. PriorityQueue of CustomComposite
pq_type = PriorityQueue("custom_elem_pq", custom_elem)
x_pq = Type(pq_type, dependencies=[custom_elem])

pqt = pq_type.variable("pqt")
x_pq.setup(f"""
  {pqt.definition};
  {pq_type.create(pqt)};
""")
x_pq.cleanup(f"""
  {pq_type.destroy(pqt)};
""")

x_pq.unit(f"{pq_type.emplace}(): emplace into priority queue", f"""
  {pq_type.emplace(pqt, 10)};
  {pq_type.emplace(pqt, 50)};
  {pq_type.emplace(pqt, 30)};
  TEST_EQUAL({pq_type.size(pqt)}, 3);
  TEST_EQUAL(*{pq_type.top_view(pqt)}->value, 50);
""")


# 4. FlatMap with CustomComposite values
fm_type = FlatMap("custom_elem_flat_map", custom_elem, "int")
x_fm = Type(fm_type, dependencies=[custom_elem])

fmt = fm_type.variable("fmt")
x_fm.setup(f"""
  {fmt.definition};
  {fm_type.create(fmt)};
""")
x_fm.cleanup(f"""
  {fm_type.destroy(fmt)};
""")

x_fm.unit(f"{fm_type.emplace}(): emplace into flat map forwarding value params", f"""
  int res1 = {fm_type.emplace(fmt, 1, 111)};
  int res2 = {fm_type.emplace(fmt, 2, 222)};
  int res3 = {fm_type.emplace(fmt, 1, 999)};
  TEST_EQUAL(res1, 1);
  TEST_EQUAL(res2, 1);
  TEST_EQUAL(res3, 0);
  TEST_EQUAL({fm_type.size(fmt)}, 2);
  TEST_EQUAL(*{fm_type.get(fmt, 1)}.value, 111);
  TEST_EQUAL(*{fm_type.get(fmt, 2)}.value, 222);
""")


# 5. ChainedHashSet of CustomComposite
chs_type = ChainedHashSet("custom_elem_hash_set", custom_elem)
x_chs = Type(chs_type, dependencies=[custom_elem])

chst = chs_type.variable("chst")
x_chs.setup(f"""
  {chst.definition};
  {chs_type.create(chst)};
""")
x_chs.cleanup(f"""
  {chs_type.destroy(chst)};
""")

x_chs.unit(f"{chs_type.emplace}(): emplace into hash set forwarding params", f"""
  int r1 = {chs_type.emplace(chst, 7)};
  int r2 = {chs_type.emplace(chst, 14)};
  int r3 = {chs_type.emplace(chst, 7)};
  TEST_EQUAL(r1, 1);
  TEST_EQUAL(r2, 1);
  TEST_EQUAL(r3, 0);
  TEST_EQUAL({chs_type.size(chst)}, 2);
""")
