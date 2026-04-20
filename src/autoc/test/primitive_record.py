from autoc.core import *
from autoc.test import *
import autoc.std as std
from autoc.record import Record


x = Type(type := Record("int_record", {"_int": "int"}))

t = type.variable("t")
t1 = type.variable("t1")
t2 = type.variable("t2")


x.setup(f"""
  {t.definition};
  {type.create(t)};
""")
x.cleanup(f"""
  // {type.destroy(t)};
""")

x.unit(f"{type.create}(): default create record", f"""
""")

x.unit(f"{type.hash}(): hash default created record", f"""
  {type.hash(t)};
""")


x.setup(f"""
  {t1.definition};
  {type.create(t1)};
  {t2.definition};
  {type.create(t2)};
""")
x.cleanup(f"""
  // {type.destroy(t1)};
  // {type.destroy(t2)};
""")

x.unit(f"{type.equal}(): compare equal default created records", f"""
  TEST_TRUE( {type.equal(t1, t2)} );
""")