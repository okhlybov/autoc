import autoc.std
from enum import Enum, auto
from autoc.module import *
from autoc.core import *


# Default composite identifier decorator
def basic_decorator(type, *args, **kws):
  return str(type.prefix) + "".join(args)


#
class Composite(Type, Entity):
 
  # Global decorator used by all Composite descentants unless set locally
  decorator = basic_decorator
  
  def __init__(self, *args, decorator=None, **kws):
    super().__init__(*args, **kws)
    self.prefix = self.name
    self.__decorator = decorator
    
  def decorate(self, *args, **kws): return (Composite.decorator if self.__decorator is None else self.__decorator)(self, *args, **kws)

  def method(self, result, identifier, parameters, visibility=None, **kws):
    try:
      ids = iter(identifier)
    except:
      ids = identifier
    f = Function(result, self.decorate(*ids), parameters, visibility=self.visibility if visibility is None else visibility, **kws)
    self.references.add(f)
    return f
  
  def _create(self, result, parameters, **kws):
    return self.method(result, "create", parameters, **kws)

  def _destroy(self, result, parameters, **kws):
    return self.method(result, "destroy", parameters, **kws)
  
  def _copy(self, result, parameters, **kws):
    return self.method(result, "copy", parameters, **kws)
  
  def _equal(self, result, parameters, **kws):
    return self.method(result, "equal", parameters, **kws)
  
  def _compare(self, result, parameters, **kws):
    return self.method(result, "compare", parameters, **kws)
  
  def _hash(self, result, parameters, **kws):
    return self.method(result, "hash", parameters, **kws)

  @property
  def rvalue_type(self):
    return Pointer(self)

  @property
  def lvalue_type(self):
    return Pointer(self)

  @property
  def in_type(self):
    return Pointer(self, constant=True)

  @property
  def out_type(self):
    return Pointer(self)


#
class Function(Function, Entity):
  
  #
  class Linkage(Enum):
    EXTERNAL = auto()
    INLINE = auto()
    
  def __init__(self, result, name, parameters={}, type=Linkage.EXTERNAL, visibility=Visibility.PUBLIC, abstract=None, *args, **kws):
    super().__init__(result, name, parameters, *args, **kws)
    self.linkage = type # FIXME reflect in the interface
    self.__visibility = visibility if isinstance(visibility, Visibility) else Visibility[visibility]
    self.__abstract = abstract
    for x in [x.base if isinstance(x, Pointer) else x for x in [autoc.std.definitions, self.result] + self.types]:
      # Pointer is a non-modularzed core type yet its base type can be
      if isinstance(x, Entity): self.dependencies.add(x)

  @property
  def linkage(self):
    return self.__linkage

  @linkage.setter
  def linkage(self, linkage):
    self.__linkage = linkage if isinstance(linkage, Function.Linkage) else Function.Linkage[linkage]

  #
  @property
  def live(self):
    return self.constraint() is True
  
  #
  @property
  def inline(self):
    return self.linkage is Function.Linkage.INLINE
  
  #
  @property
  def external(self):
    return self.linkage is Function.Linkage.EXTERNAL
  
  #
  @property
  def abstract(self):
    if self.__abstract is None:
      return self.code is None
    else:
      return self.__abstract is True
  
  # FIXME visibility should be extracted into independent mixin class
  
  #
  @property
  def public(self):
    return self.__visibility is Visibility.PUBLIC
  
  #
  @property
  def private(self):
    return self.__visibility is Visibility.PRIVATE
  
  #
  @property
  def internal(self):
    return self.__visibility is Visibility.INTERNAL
  
  #
  def render_interface(self, stream):
    super().render_interface(stream)
    if self.live and not self.internal:
      if self.inline:
        self._render_definition(stream)
      else:
        self._render_declaration(stream)
  
  #
  def render_forward_declarations(self, stream):
    super().render_forward_declarations(stream)
    if self.live and self.internal:
      if self.inline:
        self._render_definition(stream)
      else:
        self._render_declaration(stream)
  
  #
  def render_implementation(self, stream):
    super().render_implementation(stream)
    if self.live and self.external and not self.abstract:
      self._render_definition(stream)

  #  
  def _render_definition(self, stream):
    if not (self.internal or self.external):
      stream.append(self.description)
    if not self.external:
      stream.append(self.__decorator)
    stream.append(self.definition)

  #
  def _render_declaration(self, stream):
    if not self.internal:
      stream.append(self.description)
    stream.append(self.__decorator)
    stream.append(self.declaration)
    stream.append(";\n")
    
  @property
  def __decorator(self): return f"{Function.__spec[self.linkage]}\n"
  
  #
  @property
  def description(self):
    if self.public:
      return "/** @public */\n"
    else:
      return "/** @private */\n"

  __spec = {Linkage.INLINE: "AUTOC_STATIC_INLINE", Linkage.EXTERNAL: "AUTOC_EXTERN"}