from functools import cached_property
from enum import Enum, auto
from autoc.module import *
from autoc.core import *
import autoc.std


def default_decorator(type, identifier, **kws): return f"{type.prefix}{identifier}"


#
class Composite(Type, Entity):
 
  decorator = default_decorator
  
  def __init__(self, *args, decorator=None, **kws):
    super().__init__(*args, **kws)
    self.prefix = self.name
    self.__decorator = decorator
    
  def decorate(self, identifier, **kws): return (Composite.decorator if self.__decorator is None else self.__decorator)(self, identifier, **kws)

  def method(self, result, identifier, parameters, **kws):
    f = Function(result, self.decorate(identifier), parameters, **kws)
    self.references.add(f)
    return f
  
  def _create(self, result, parameters, **kws): return self.method(result, "create", parameters, **kws)

  def _destroy(self, result, parameters, **kws): return self.method(result, "destroy", parameters, **kws)
  
  def _copy(self, result, parameters, **kws): return self.method(result, "copy", parameters, **kws)
  
  def _equal(self, result, parameters, **kws): return self.method(result, "equal", parameters, **kws)
  
  def _compare(self, result, parameters, **kws): return self.method(result, "compare", parameters, **kws)
  
  def _hash(self, result, parameters, **kws): return self.method(result, "hash", parameters, **kws)

  @cached_property
  def rvalue_type(self): return Pointer(self)

  @cached_property
  def lvalue_type(self): return Pointer(self)

  @cached_property
  def in_type(self): return Pointer(self)

  @cached_property
  def out_type(self): return Pointer(self)


#
class Function(Function, Entity):
  
  #
  class Type(Enum):
    EXTERNAL = auto()
    INLINE = auto()
    
  #
  class Visibility(Enum):
    PUBLIC = auto()
    PRIVATE = auto()
    INTERNAL = auto()
    
  def __init__(self, result, name, parameters={}, type=Type.EXTERNAL, visibility=Visibility.PUBLIC, abstract=False, *args, **kws):
    super().__init__(result, name, parameters, *args, **kws)
    self.__type = type if isinstance(type, Function.Type) else Function.Type[type]
    self.__visibility = visibility if isinstance(visibility, Function.Visibility) else Function.Visibility[visibility]
    self.__abstract = abstract
    for x in [x.base if isinstance(x, Pointer) else x for x in [Function.__definitions, self.result] + self.types]:
      # Pointer is a non-modularzed core type yet its base type can be
      if isinstance(x, Entity): self.dependencies.add(x)

  #
  @property
  def live(self): return self.constraint() is True
  
  #
  @property
  def inline(self): return self.__type is Function.Type.INLINE
  
  #
  @property
  def external(self): return self.__type is Function.Type.EXTERNAL
  
  #
  @property
  def abstract(self): return self.__abstract is True
  
  #
  @property
  def public(self): return self.__visibility is Function.Visibility.PUBLIC
  
  #
  @property
  def private(self): return self.__visibility is Function.Visibility.PRIVATE
  
  #
  @property
  def internal(self): return self.__visibility is Function.Visibility.INTERNAL
  
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
    if not (self.internal or self.external): stream.append(self.description)
    if not self.external: stream.append(self.__decorator)
    stream.append(self.definition)

  #
  def _render_declaration(self, stream):
    if not self.internal: stream.append(self.description)
    stream.append(self.__decorator)
    stream.append(self.declaration)
    stream.append(";")
    
  @cached_property
  def __decorator(self): return f"{Function.__spec[self.__type]}\n"
  
  #
  @property
  def description(self):
    if self.public:
      return "/* @public */"
    else:
      return "/* @private */"

  __spec = {Type.INLINE: "AUTOC_STATIC_INLINE", Type.EXTERNAL: "AUTOC_EXTERN"}
  
  __definitions = Code(
    interface="""
      #ifndef AUTOC_EXTERN
        #ifdef __cplusplus
          #define AUTOC_EXTERN extern "C"
        #else
          #define AUTOC_EXTERN extern
        #endif
      #endif
      #ifndef AUTOC_STATIC_INLINE
        #if defined(__cplusplus) || (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L)
          #define AUTOC_STATIC_INLINE static inline
        #else
          #define AUTOC_STATIC_INLINE static
        #endif
      #endif
    """
  )