from autoc.test import *
from autoc.static_vector import StaticVector
from autoc.test.primitive_arc import type as arc

x = Type(type := StaticVector("arc_static_vector", arc, 3))

t = type.variable("t")
t1 = type.variable("t1")
t2 = type.variable("t2")
p = arc.variable("p")
p_out = arc.variable("p_out")


x.setup(f"""
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.push}(): push composite references to static vector", f"""
  {p.definition};
  {arc.create(p)};
  *p = 10;
  {type.push(t, p)};
  {arc.destroy(p)};

  {arc.create(p)};
  *p = 20;
  {type.push(t, p)};
  {arc.destroy(p)};

  TEST_EQUAL( {type.size(t)}, 2 );
  TEST_EQUAL( *{type.front_view(t)}, 10 );
  TEST_EQUAL( *{type.back_view(t)}, 20 );
""")

x.unit(f"{type.pop}(): pop composite reference from static vector", f"""
  {p.definition};
  {p_out.definition};
  {arc.create(p)};
  *p = 100;
  {type.push(t, p)};
  {arc.destroy(p)};

  {p_out} = {type.pop(t)};
  TEST_EQUAL( *{p_out}, 100 );
  TEST_TRUE( {type.empty(t)} );
  {arc.destroy(p_out)};
""")

x.unit(f"{type.clear}(): clear static vector of composite elements", f"""
  {p.definition};
  {arc.create(p)};
  *p = 50;
  {type.push(t, p)};
  {arc.destroy(p)};

  {arc.create(p)};
  *p = 60;
  {type.push(t, p)};
  {arc.destroy(p)};

  TEST_EQUAL( {type.size(t)}, 2 );
  {type.clear(t)};
  TEST_TRUE( {type.empty(t)} );
  TEST_EQUAL( {type.size(t)}, 0 );
""")


x.setup(f"""
  {t1.definition};
  {type.create(t1)};
  {t2.definition};
  {type.create(t2)};
""")
x.cleanup(f"""
  {type.destroy(t1)};
  {type.destroy(t2)};
""")

x.unit(f"{type.copy}(): copy static vector with composite elements", f"""
  {p.definition};
  {arc.create(p)};
  *p = 42;
  {type.push(t1, p)};
  {arc.destroy(p)};

  {type.copy(t2, t1)};
  TEST_TRUE( {type.equal(t1, t2)} );
  TEST_EQUAL( {type.size(t2)}, 1 );
  TEST_EQUAL( *{type.front_view(t2)}, 42 );
""")

x.unit(f"{type.move}(): move static vector with composite elements", f"""
  {p.definition};
  {arc.create(p)};
  *p = 88;
  {type.push(t1, p)};
  {arc.destroy(p)};

  {type.move(t2, t1)};
  TEST_TRUE( {type.empty(t1)} );
  TEST_EQUAL( {type.size(t2)}, 1 );
  TEST_EQUAL( *{type.front_view(t2)}, 88 );
""")
