import autoc.core
from autoc.composite import Composite


#
class Record(Composite, autoc.core._Disabled):
  
  def __init__(self, name, fields={}, *args, **kws):
    super().__init__(name, *args, **kws)
    self.fields = {str(name): autoc.core._type(type) for name, type in fields.items()}
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
      self.equal.code = ["assert(left);assert(right);", "return ", " && ".join([str(type.equal(f"left->{field}", f"right->{field}")) for field, type in self.fields.items()]), ";"]
      
    if self.copyable:
      code = []
      code.append("assert(target);assert(source);")
      for field, type in self.fields.items():
        code.append(type.copy(f"target->{field}", f"source->{field}"))
        code.append(";")
      self.copy.code = code
      
    # TODO hash

  def _render_struct(self, stream):
    stream.append("typedef struct {\n")
    for field, type in self.fields.items():
      stream.append(f"{type} {field};")
      if self.private:
        stream.append("/**< @private */\n")
      else:
        stream.append("\n")
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
