import autoc.hash
from autoc.composite import Composite, Method
from autoc.core import out
import autoc.std as std

#
class Record(Composite):
  
  def __init__(self, name, fields, hasher=autoc.hash.Hasher(), getters=True, setters=True, opaque=True, dependencies=[], *args, **kws):
    super().__init__(name, dependencies=[*dependencies, std.assert_h, hasher], *args, **kws)
    self.fields = {str(name): autoc.core._type(type) for name, type in fields.items()}
    self.hasher = hasher
    self.getters = getters
    self.setters = setters
    self.opaque = opaque
    self._depend_on(*self.fields.values())

  def __setup__(self):
    super().__setup__()
    
    if self.constructible:
      code = []
      code.append("assert(target);")
      for field, type in self.fields.items():
        code.append(type.create(type.variable(f"target->{field}")))
        code.append(";")
      self.create.code = code
      self.create.linkage = "INLINE"
    
    if self.destructible:
      code = []
      code.append("assert(target);")
      for field, type in self.fields.items():
        if type.destructible:
          code.append(type.destroy(type.variable(f"target->{field}")))
          code.append(";")
      self.destroy.code = code
      self.destroy.linkage = "INLINE"

    if self.comparable:
      xs = []
      for field, type in self.fields.items():
        xs.append(str(type.equal(type.variable(f"left->{field}"), type.variable(f"right->{field}"))))
      self.equal.code = ["assert(left); assert(right);", "return ", " && ".join(xs if xs else ["1"]), ";"]
      self.equal.linkage = "INLINE"
      
    if self.copyable:
      code = []
      code.append("assert(target); assert(source);")
      for field, type in self.fields.items():
        code.append(type.copy(type.variable(f"target->{field}"), type.variable(f"source->{field}")))
        code.append(";")
      self.copy.code = code
      self.copy.linkage = "INLINE"
      
    if self.hashable:
      code = []
      state = self.hasher.state_t.variable("state")
      code.append(f"{state.definition}; size_t result; assert(target); {self.hasher.create(state)};")
      for field, type in self.fields.items():
        code.append(self.hasher.update(state, type.hash(type.variable(f"target->{field}"))))
        code.append(";")
      code.append(f"result = {self.hasher.hash(state)}; {self.hasher.destroy(state)}; return result;")
      self.hash.code = code
      self.hash.linkage = "INLINE"


    if self.getters:
      for field, type in self.fields.items():
        self._add_reader(type, field)

    if self.setters:
      for field, type in self.fields.items():
        self._add_writer(type, field)

  def _add_reader(self, type, field):
    result = type.variable("result")
    self.references.add(Method(type, self._getter_name(field), {"target": self}, visibility=self.visibility, linkage="INLINE", code = f"""
      {result.definition};
      assert(target);
      {type.copy(result, type.variable(f"target->{field}"))};
      return {result};
    """))

  def _add_writer(self, type, field):
    destroy_field = type.destroy(type.variable(f"target->{field}")) if type.destructible else str()
    self.references.add(Method(None, self._setter_name(field), {"target": out(self), "value": type}, visibility=self.visibility, linkage="INLINE", code = f"""
      assert(target);
      {destroy_field};
      {type.copy(type.variable(f"target->{field}"), "value")};
    """))

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
  
  def render_interface(self, stream):
    super().render_interface(stream)
    if not self.internal:
      self._render_struct(stream)

  def render_forward_declarations(self, stream):
    super().render_forward_declarations(stream)
    if self.internal:
      self._render_struct(stream)
