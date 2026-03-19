import autoc.core
import autoc.hash
import autoc.composite
from autoc.core import out, Visibility

#
class Record(autoc.composite.Composite):
  
  def __init__(self, name, fields={}, hasher=autoc.hash.Hasher(), readers=True, writers=True, glassbox=False, *args, **kws):
    super().__init__(name, *args, **kws)
    self.fields = {str(name): autoc.core._type(type) for name, type in fields.items()}
    self.hasher = hasher
    self.readers = readers
    self.writers = writers
    self.glassbox = glassbox
    self.dependencies.add(hasher)
    for type in self.fields.values():
      self.dependencies.add(type)

  def __setup__(self):
    super().__setup__()
    
    if self.constructible:
      code = []
      code.append("assert(target);")
      for field, type in self.fields.items():
        code.append(type.create(f"target->{field}"))
        code.append(";")
      self.create.code = code
    
    if self.destructible:
      code = []
      code.append("assert(target);")
      for field, type in self.fields.items():
        if type.destructible:
          code.append(type.destroy(f"target->{field}"))
          code.append(";")
      self.destroy.code = code

    if self.comparable:
      self.equal.code = ["assert(left);assert(right);", "return ", " && ".join([str(type.equal(f"left->{field}", f"right->{field}")) for field, type in self.fields.items()] + ["1"]), ";"]
      
    if self.copyable:
      code = []
      code.append("assert(target);assert(source);")
      for field, type in self.fields.items():
        code.append(type.copy(f"target->{field}", f"source->{field}"))
        code.append(";")
      self.copy.code = code
      
    if self.hashable:
      code = []
      code.append(f"{self.hasher.state_t} state; size_t result; assert(source); {self.hasher.create("state")};")
      for field, type in self.fields.items():
        code.append(self.hasher.update("state", type.hash(f"source->{field}")))
        code.append(";")
      code.append(f"result = {self.hasher.hash("state")}; {self.hasher.destroy("state")}; return result;")
      self.hash.code = code

    if self.readers:
      for field, type in self.fields.items():
        self._add_reader(type, field)

    if self.writers:
      for field, type in self.fields.items():
        self._add_writer(type, field)

  def _add_reader(self, type, field):
    self.references.add(autoc.composite.Function(type, self._reader_name(field), {"target": self}, visibility=self.visibility, type=autoc.composite.Function.Linkage.INLINE, code = f"""
      {type} result;
      assert(target);
      {type.copy("result", f"target->{field}")};
      return result;
    """))

  def _add_writer(self, type, field):
    destroy_field = type.destory(f"target->{field}") if type.destructible else str()
    self.references.add(autoc.composite.Function(None, self._writer_name(field), {"target": out(self), "value": type}, visibility=self.visibility, type=autoc.composite.Function.Linkage.INLINE, code = f"""
      assert(target);
      {destroy_field};
      {type.copy(f"target->{field}", "value")};
    """))

  def _reader_name(self, field): return self.decorate(field)
    
  def _writer_name(self, field): return self.decorate("set", field)

  def _render_struct(self, stream):
    if self.public:
      stream.append("/** @public */\n")
    if self.private:
      stream.append("/** @private */\n")
    stream.append("typedef struct {\n")
    for field, type in self.fields.items():
      stream.append(f"{type} {field};")
      if not self.internal:
        if self.private or not self.glassbox:
          stream.append("/**< @private */\n")
        else:
          stream.append("/**< @public */\n")
    stream.append(f"}} {self.name};\n")
    
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
