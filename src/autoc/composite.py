import autoc.std
import autoc.memory
from autoc.core import *
from enum import Enum, auto
from autoc.module import Entity


# _snake_case identifier decorator
def snake_decorator(type, identifier):
  ids = [identifier] if isinstance(identifier, str) else [*identifier]
  return  "_".join([str(type.prefix)] + ids)


# CamelCase identifier decorator
def camel_decorator(type, identifier):
  ids = [identifier] if isinstance(identifier, str) else [*identifier]
  return  "".join([str(type.prefix)] + [s[0].upper()+s[1:] for s in ids])


#
class Composite(Type, Entity):
 
  # Global decorator used by all Composite descentants unless overridden locally
  decorator = camel_decorator
  
  def __init__(self, *args, decorator=None, **kws):
    super().__init__(*args, **kws)
    self.prefix = self.name
    self.__decorator = decorator
    
  def decorate(self, *args, **kws):
    identifier = args if len(args) > 1 else args[0]
    return (Composite.decorator if self.__decorator is None else self.__decorator)(self, identifier, **kws)
  
  def method(self, result, identifier, parameters, visibility=None, **kws):
    f = Function(result, self.decorate(identifier), parameters, visibility=self.visibility if visibility is None else visibility, **kws)
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

  @property
  def inout_type(self):
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


class Arc(Composite, autoc.core.TraitsDisabler):
    
  def __init__(self, name, type, *args, **kws):
    super().__init__(name, *args, **kws)
    self.type = autoc.core._type(type)
    self.alias = Pointer(self.type)

  def __setup__(self):
    super().__setup__()

    result = Variable(self.alias, "result")

    self.new = self.method(self, "new", {}, code=f"""
      {result.definition};
      {self.type.create(result)};
      return result;
    """)
    
    destroy = self.type.destroy(Variable(self.alias, "target")) if self.type.destructible else str()
    self.free = self.method(None, "free", {"target": inout(self)}, code=f"""
      assert(target);
      {destroy};
    """)
    
    self.share = self.method(self, "share", {"target": inout(self)}, code=f"""
      assert(target);
      return target;
    """)

  def _render_struct(self, stream):
    if self.public:
      stream.append("/** @public */\n")
    if self.private:
      stream.append("/** @private */\n")
    stream.append(f"typedef {self.alias} {self.name};\n")

  def render_interface(self, stream):
    super().render_interface(stream)
    if not self.internal:
      self._render_struct(stream)

  def render_forward_declarations(self, stream):
    super().render_forward_declarations(stream)
    if self.internal:
      self._render_struct(stream)

  @property
  def constructible(self):
    return self.type.constructible

  def _create(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target: f"{target} = {self.new()}", **kws)

  @property
  def destructible(self):
    return True

  def _destroy(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target: str(self.free(target)), **kws)

  @property
  def copyable(self):
    return True
  
  def _copy(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target, source: f"{target} = {self.share(source)}", **kws)

  @property
  def comparable(self):
    return self.type.comparable

  def _equal(self, result, parameters, **kws):
    return Macro(result, parameters, lambda left, right: str(self.type.equal(left, right)), **kws)
  
  @property
  def hashable(self):
    return self.type.hashable
  
  def _hash(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target: str(self.type.hash(target)), **kws)

  @property
  def orderable(self):
    return self.type.orderable
  
  def _compare(self, result, parameters, **kws):
    return Macro(result, parameters, lambda left, right: str(self.type.compare(left, right)), **kws)
  
  @property
  def rvalue_type(self):
    return self

  @property
  def lvalue_type(self):
    return self

  @property
  def in_type(self):
    return self

  @property
  def out_type(self):
    return Pointer(self)

  @property
  def inout_type(self):
    return self