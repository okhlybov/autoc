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
    self.__type = type
    self.__visibility = visibility
    self.__abstract = abstract
    for x in [x.base if isinstance(x, Pointer) else x for x in [Function.__definitions, self.result] + self.types]:
      # Pointer is a non-modularzed core type yet its base type can be
      if isinstance(x, Entity): self.dependencies.add(x)

  #
  def is_live(self): return self.constraint() is True
  
  #
  def is_inline(self): return self.__type is Function.Type.INLINE
  
  #
  def is_external(self): return self.__type is Function.Type.EXTERNAL
  
  #
  def is_abstract(self): return self.__abstract is True
  
  #
  def is_public(self): return self.__visibility is Function.Visibility.PUBLIC
  
  #
  def is_private(self): return self.__visibility is Function.Visibility.PRIVATE
  
  #
  def is_internal(self): return self.__visibility is Function.Visibility.INTERNAL
  
  #
  def render_interface(self, stream):
    super().render_interface(stream)
    if self.is_live():
      self.__stream = stream
      if not self.is_internal(): self._declaration()
  
  #
  def render_forward_declarations(self, stream):
    super().render_forward_declarations(stream)
    if self.is_live():
      self.__stream = stream
      if self.is_internal(): self._declaration()
  
  #
  def render_implementation(self, stream):
    super().render_implementation(stream)
    if self.is_live():
      self.__stream = stream
      self._declaration()
  
  #
  def _declaration(self):
    self._header()
    self.__stream.append(f"{Function.__spec[self.__type]}\n")
    self.__stream.append(self.declaration())
    
  #
  def _header(self):
    if self.is_public():
      self.__stream.append("/* @public */")
    else:
      self.__stream.append("/* @private */")

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