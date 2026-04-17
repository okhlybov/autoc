import re
import autoc.std
import autoc.core
from autoc.core import *
from enum import Enum, auto
from autoc.module import Entity
import autoc.std as std
import autoc.memory
import autoc.hash


def _hidden_prefix(s, hidden):
  m = re.match("^(_*)(.*)", s)
  u = m.group(1)
  if not u and hidden:
    u = "_" # Prepend single underscore for a symbol marked hidden that is not already underscored
  return u + m.group(2)


# _snake_case identifier decorator
def snake_decorator(type, identifier, hidden=False):
  ids = []
  if identifier:
    ids = [identifier] if isinstance(identifier, str) else [*identifier]
  return _hidden_prefix("_".join([str(type.prefix)] + ids), hidden)


# CamelCase identifier decorator
def camel_decorator(type, identifier, hidden=False):
  ids = []
  if identifier:
    ids = [identifier] if isinstance(identifier, str) else [*identifier]
  return _hidden_prefix("".join([str(type.prefix)] + [s[0].upper()+s[1:] for s in ids]), hidden)


#
class Composite(Type, Entity):
 
  # Global decorator used by all Composite descentants unless overridden locally
  decorator = camel_decorator
  
  def __init__(self, name, *args, prefix=None, decorator=None, inline_methods=None, **kws):
    super().__init__(name, *args, **kws)
    self.prefix = prefix if prefix else self.name
    self.__decorator = decorator
    self.__inline_policy = inline_methods

  def decorate(self, *args, **kws):
    identifier = args if len(args) > 1 else args[0]
    return (Composite.decorator if self.__decorator is None else self.__decorator)(self, identifier, **kws)

  def method(self, result, identifier, parameters, visibility=None, hidden=False, dependencies=[], **kws):
    m = Method(result, self.decorate(identifier, hidden=hidden), parameters, dependencies=[self, *dependencies], visibility=self.visibility if visibility is None else visibility, **kws)
    self.references.add(m)
    return m

  def _inline_policy(self, method):
    match self.__inline_policy:
      case True:
        method.linkage = "INLINE"
      case False:
        method.linkage = "EXTERNAL"

  # 
  def depends(self, *entities):
    for entity in entities:
      self.dependencies.update([*entity.dependencies, *entity.references, entity])

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
class Method(Function, Entity):

  #
  class Linkage(Enum):
    EXTERNAL = auto()
    INLINE = auto()

  def __init__(self, result, name, parameters, *args, linkage="EXTERNAL", visibility="PUBLIC", abstract=None, dependencies=[], **kws):
    super().__init__(result, name, parameters, *args, **kws)
    self.linkage = linkage
    self.__visibility = visibility if isinstance(visibility, Visibility) else Visibility[visibility]
    self.__abstract = abstract
    for x in [autoc.std.linkage, self.result] + self.types + dependencies:
      if isinstance(x, Entity):
        self.dependencies.add(x)
      else:
        # Pointer is a non-modularzed core type yet its base type can be
        if isinstance(x, Pointer) and isinstance(x.base, Entity):
          self.dependencies.add(x.base)


  @property
  def linkage(self):
    return self.__linkage

  @linkage.setter
  def linkage(self, linkage):
    self.__linkage = linkage if isinstance(linkage, Method.Linkage) else Method.Linkage[linkage]

  #
  @property
  def live(self):
    return self.constraint() is True

  #
  @property
  def inline(self):
    return self.linkage is Method.Linkage.INLINE

  #
  @property
  def external(self):
    return self.linkage is Method.Linkage.EXTERNAL

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
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if self.live:
      if (header and not self.internal) or (not header and self.internal):
        self._render_declaration(stream)

  #
  def render_definitions(self, stream, header):
    super().render_definitions(stream, header)
    if self.live:
      if self.inline:
        if (header and not self.internal) or (not header and self.internal):
          self._render_definition(stream)
      else:
        if not header:
          self._render_definition(stream)

  #  
  def _render_definition(self, stream):
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
  def __decorator(self): return f"{Method.__spec[self.linkage]}\n"
  
  #
  @property
  def description(self):
    if self.public:
      return "/** @public */\n"
    else:
      return "/** @private */\n"

  __spec = {Linkage.INLINE: "AUTOC_STATIC_INLINE", Linkage.EXTERNAL: "AUTOC_EXTERN"}
  
  
#
class Collection(Composite):
  
  def __init__(self, name, element, memory=autoc.memory.Manager(), hasher=None, dependencies=[], *args, **kws):
    super().__init__(name, dependencies=[*dependencies, std.assert_h, memory, hasher], *args, **kws)
    self.element = autoc.core._type(element)
    self.element_view = Pointer(self.element, constant=True)
    self.depends(self.element)
    self.memory = memory
    self.hasher = hasher

  def __setup__(self):
    super().__setup__()
    self.empty = self.method("int", "empty", {"target": self})
    self.size = self.method(std.size_t, "size", {"target": self})

  @property
  def constructible(self):
    return True
  
  @property
  def destructible(self):
    return True

  @property
  def copyable(self):
    return self.element.copyable
  
  @property
  def hashable(self):
    return self.element.hashable

  @property
  def comparable(self):
    return self.element.comparable
  
  @property
  def orderable(self):
    return False


class _StructRenderer:
  
  # def _render_struct(stream)
  
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if (header and not self.internal) or (not header and self.internal):
      self._render_struct(stream)