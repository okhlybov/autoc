from autoc.test import Type as _Type
from autoc.core import Composite, _StructRenderer, out


# Custom composite value type
class Type(_StructRenderer, Composite):
  
  def __setup__(self):
    super().__setup__()
    
    with self.method(None, "create", {"target": out(self), "value": "int"}) as f:
      f.code = """
        target->value = (int*)malloc(sizeof(int));
        *target->value = value;
      """
    with self.destroy as f:
      f.code = "free(target->value);"
    with self.copy as f:
      f.code = """
        target->value = (int*)malloc(sizeof(int));
        *target->value = *source->value;
      """
    with self.equal as f:
      f.code = "return *left->value == *right->value;"
    with self.compare as f:
      f.code = "return *left->value == *right->value ? 0 : (*left->value > *right->value ? +1 : -1);"
    with self.hash as f:
      f.code = "return *target->value;"
    
  def _render_struct(self, stream):
    stream.append(f"""
      typedef struct {{
        int* value;
      }} {self.name};
    """)
    

x = _Type(type := Type("custom_composite"))

t = type.variable("t")
t2 = type.variable("t2")


x.setup(f"""
  {t.definition};
  {type.create(t, -1)};
""")
x.cleanup(f"""
  {type.destroy(t)};
""")

x.unit(f"{type.create}(): create value", f"""
""")

x.unit(f"{type.copy}(): copy value", f"""
  {t2.definition};
  {type.copy(t2, t)};
  TEST_TRUE( {type.equal(t2, t)} );
  {type.destroy(t2)};
""")