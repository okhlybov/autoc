from functools import cached_property
from enum import Enum, auto
from autoc.module import *
from autoc.core import *
import autoc.std


#
class Composite(autoc.core.Type, Entity):

  def is_constructible(self): return True
  def _construct(self, result, parameters, **kws): pass

  def is_destructible(self): return False
  def _destroy(self, result, parameters, **kws): pass
  
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
        self.render_definition(stream)
      else:
        self.render_declaration(stream)
  
  #
  def render_forward_declarations(self, stream):
    super().render_forward_declarations(stream)
    if self.live and self.internal:
      if self.inline:
        self.render_definition(stream)
      else:
        self.render_declaration(stream)
  
  #
  def render_implementation(self, stream):
    super().render_implementation(stream)
    if self.live and self.external and not self.abstract:
      self.render_definition(stream)

  #  
  def render_definition(self, stream):
    if not (self.internal or self.external): stream.append(self.description())
    if not self.external: stream.append(self._decorator)
    stream.append(self.definition())

  #
  def render_declaration(self, stream):
    if not self.internal: stream.append(self.description())
    stream.append(self._decorator)
    stream.append(self.declaration())
    stream.append(";")
    
  @cached_property
  def _decorator(self): return f"{Function.__spec[self.__type]}\n"
  
  #
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