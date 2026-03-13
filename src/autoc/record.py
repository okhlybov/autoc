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
    code = []
    for field, type in self.fields.items():
      code.append(type.create(field) + ";\n")
    self.create.code=code
    
  def __render_struct(self, stream):
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

  def render_interface(self, stream):
    super().render_interface(stream)
    if not self.internal:
      self.__render_struct(stream)

  def render_forward_declarations(self, stream):
    super().render_forward_declarations(stream)
    if self.internal:
      self.__render_struct(stream)
