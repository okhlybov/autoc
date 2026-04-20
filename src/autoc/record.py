import autoc.hash
from autoc.composite import Composite, Method, _StructRenderer
from autoc.core import out
import autoc.std as std


#
class Record(_StructRenderer, Composite):
  
  def __init__(self, name, fields, hasher=autoc.hash.XorShift(), getters=True, setters=True, opaque=True, dependencies=[], *args, **kws):
    super().__init__(name, *args, dependencies=[*dependencies, std.assert_h, hasher], **kws)
    self.fields = {str(name): autoc.core._type(type) for name, type in fields.items()}
    self.hasher = hasher
    self.getters = getters
    self.setters = setters
    self.opaque = opaque
    self.depends(*self.fields.values())

  def __setup__(self):
    super().__setup__()
    
    code = []
    self.create.linkage = "INLINE"
    code.append("assert(target);")
    for field, type in self.fields.items():
      code.append(type.create(type.variable(f"target->{field}")))
      code.append(";")
    self.create.code = code
    self._inline_policy(self.create)
    
    code = []
    self.destroy.linkage = "INLINE"
    code.append("assert(target);")
    for field, type in self.fields.items():
      if type.destructible:
        code.append(type.destroy(type.variable(f"target->{field}")))
        code.append(";")
    self.destroy.code = code
    self._inline_policy(self.destroy)

    xs = []
    self.equal.linkage = "INLINE"
    for field, type in self.fields.items():
      xs.append(str(type.equal(type.variable(f"left->{field}"), type.variable(f"right->{field}"))))
    self.equal.code = ["assert(left); assert(right);", "return ", " && ".join(xs if xs else ["1"]), ";"]
    self._inline_policy(self.equal)
      
    code = []
    self.copy.linkage = "INLINE"
    code.append("assert(target); assert(source);")
    for field, type in self.fields.items():
      code.append(type.copy(type.variable(f"target->{field}"), type.variable(f"source->{field}")))
      code.append(";")
    self.copy.code = code
    self._inline_policy(self.copy)
      
    code = []
    self.hash.linkage = "INLINE"
    state = self.hasher.state_t.variable("state")
    code.append(f"{state.definition}; size_t result; assert(target); {self.hasher.create(state)};")
    for field, type in self.fields.items():
      code.append(self.hasher.update(state, type.hash(type.variable(f"target->{field}"))))
      code.append(";")
    code.append(f"result = {self.hasher.hash(state)}; {self.hasher.destroy(state)}; return result;")
    self.hash.code = code
    self._inline_policy(self.hash)

    if self.getters:
      for field, type in self.fields.items():
        self._add_reader(type, field)

    if self.setters:
      for field, type in self.fields.items():
        self._add_writer(type, field)

  def _add_reader(self, type, field):
    result = type.variable("result")
    self.references.add(m := Method(type, self._getter_name(field), {"target": self}, visibility=self.visibility, linkage="INLINE", code = f"""
      {result.definition};
      assert(target);
      {type.copy(result, type.variable(f"target->{field}"))};
      return {result};
    """))
    self._inline_policy(m)

  def _add_writer(self, type, field):
    destroy_field = type.destroy(type.variable(f"target->{field}")) if type.destructible else str()
    self.references.add(m := Method(None, self._setter_name(field), {"target": out(self), "value": type}, visibility=self.visibility, linkage="INLINE", code = f"""
      assert(target);
      {destroy_field};
      {type.copy(type.variable(f"target->{field}"), "value")};
    """))
    self._inline_policy(m)

  def _getter_name(self, field): return self.decorate(field)
    
  def _setter_name(self, field): return self.decorate("set", field)

  def _render_struct(self, stream):
    if self.public:
      stream.append("/** @public */\n")
    if self.private:
      stream.append("/** @private */\n")
    stream.append(f"typedef struct {self.name} {self.name};\n")
    if self.opaque or self.private:
      stream.append("/** @private */\n")
    else:
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