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

x.unit(f"{type.empty}()", f"""
  TEST_TRUE( {type.empty(t)} );
""")

x.unit(f"!{type.empty}()", f"""
  {type.push_front(t, 0)};
  TEST_FALSE( {type.empty(t)} );
""")