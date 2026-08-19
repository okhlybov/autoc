import autoc2.std as std
from autoc2.hash import XorRot
from autoc2.core import out, _type
from autoc2.composite import Composite, _StructRenderer


#
class Record(_StructRenderer, Composite):
  
  def __init__(self, name, fields, hasher=XorRot(), getters=True, setters=True, opaque=True, dependencies=tuple(), *args, **kws):
    super().__init__(name, *args, dependencies=(*dependencies, std.assert_h, hasher), **kws)
    self.fields = {str(name): _type(type) for name, type in fields.items()}
    self.hasher = hasher
    self.getters = getters
    self.setters = setters
    self.opaque = opaque
    self.depend(*self.fields.values())

  def __setup__(self):
    super().__setup__()
    
    # FIXME assert arguments when they are pointers
    
    with self.create as f:
      code = []
      target = f"({f.target.bind(self)})"
      for field, type in self.fields.items():
        code.append(type.create(type.variable(f"{target}.{field}")))
        code.append(";")
      f.inline_code = code
    
    with self.destroy as f:
      code = []
      target = f"({f.target.bind(self)})"
      for field, type in self.fields.items():
        if type.destructible:
          code.append(type.destroy(type.variable(f"{target}.{field}")))
          code.append(";")
      f.inline_code = code

    with self.equal as f:
      xs = []
      left = f"({f.left.bind(self)})"
      right = f"({f.right.bind(self)})"
      for field, type in self.fields.items():
        xs.append(str(type.equal(type.variable(f"{left}.{field}"), type.variable(f"{right}.{field}"))))
      f.inline_code = ["return ", " && ".join(xs if xs else ["1"]), ";"]
      
    with self.copy as f:
      code = []
      target = f"({f.target.bind(self)})"
      source = f"({f.source.bind(self)})"
      for field, type in self.fields.items():
        code.append(type.copy(type.variable(f"{target}.{field}"), type.variable(f"{source}.{field}")))
        code.append(";")
      f.inline_code = code
      
    with self.hash as f:
      code = []
      target = f"({f.target.bind(self)})"
      state = self.hasher.state_t.variable("state")
      code.append(f"{state.definition}; size_t result; {self.hasher.create(state)};")
      for field, type in self.fields.items():
        code.append(self.hasher.update(state, type.hash(type.variable(f"{target}.{field}"))))
        code.append(";")
      code.append(f"result = {self.hasher.hash(state)}; {self.hasher.destroy(state)}; return result;")
      f.inline_code = code

    if self.getters:
      for field, type in self.fields.items():
        self._add_reader(type, field)

    if self.setters:
      for field, type in self.fields.items():
        self._add_writer(type, field)

  def _add_reader(self, type, field):
    with self.method(type, field, {"target": self}, attribute=("get", field), visibility=self.visibility, constraint=lambda: type.copyable) as f:
      result = f.result.variable("result")
      target = f"({f.target.bind(self)})"
      f.inline_code = f"""
        {result.definition};
        {type.copy(result, type.variable(f"{target}.{field}"))};
        return {result};
      """

  def _add_writer(self, type, field):
    with self.method(None, ("set", field), {"target": out(self), "value": type}, visibility=self.visibility, constraint=lambda: type.copyable) as f:
      target = f"({f.target.bind(self)})"
      destroy_field = type.destroy(type.variable(f"{target}.{field}")) if type.destructible else str()
      f.inline_code = f"""
        {destroy_field};
        {type.copy(type.variable(f"{target}.{field}"), "value")};
      """

  def _getter_name(self, field):
    return self.decorate(field)
    
  def _setter_name(self, field):
    return self.decorate("set", field)

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"typedef struct {self.name} {self.name};\n")
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"struct {self.name} {{\n")
    for field, type in self.fields.items():
      stream.append(f"{type} {field};")
      if not self.internal:
        if self.opaque or self.private:
          stream.append("/**< @private */\n")
        else:
          stream.append("/**< @public */\n")
    stream.append("};\n")
    
  @property
  def constructible(self):
    return all(type.constructible for type in self.fields.values())

  @property
  def destructible(self):
    return any(type.destructible for type in self.fields.values())

  @property
  def comparable(self):
    return all(type.comparable for type in self.fields.values())
  
  @property
  def copyable(self):
    return all(type.copyable for type in self.fields.values())

  @property
  def hashable(self):
    return all(type.hashable for type in self.fields.values())

  @property
  def orderable(self):
    return False