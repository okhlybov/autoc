import re
import sys
from autoc.core import Type, Indirection, _Traitful, Macro, Function


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


# Global decorator used by all Composite descentants unless overridden locally
decorator = camel_decorator


#
class Composite(Type, _Traitful):

  def __init__(self, name, *args, prefix=None, decorator=None, **kws):
    super().__init__(*args, **kws)
    self.name = str(name)
    self.prefix = prefix if prefix else self.name
    self.decorator = decorator if decorator else sys.modules[__name__].decorator
    self.__attributes = set()

  #
  def method(self, result, identifier, parameters, *args, hidden=False, attribute=None, abstract=None, **kws):
    x = Function(
      result,
      self.decorate(identifier, hidden=hidden),
      parameters,
      *args,
      abstract=abstract if abstract else False,
      **kws
    )
    # Method by itself does not depend on its owning type - only though explicit parameters
    attribute = self._decorate_attribute(attribute if attribute else identifier)
    self.__attributes.add(attribute) # Record attribute name which holds the method object
    setattr(self, attribute, x)
    return x

  #
  def macro(self, attribute, *args, **kws):
    self.__attributes.add(attribute) # Record attribute name which holds the method object
    setattr(self, attribute, x := Macro(*args, **kws))
    return x
  
  #
  def macro_from(self, attribute, *args, **kws):
    m = getattr(self, attribute)
    return self.macro(attribute, m._result, m._parameters, *args, **kws)
    
  #
  def method_from(self, identifier, *args, attribute=None, **kws):
    m = getattr(self, attribute := self._decorate_attribute(attribute if attribute else identifier))
    return self.method(m._result, identifier, m._parameters, *args, constraint=m.constraint, attribute=attribute, **kws)
  
  #
  def decorate(self, *args, **kws):
    identifier = args if len(args) > 1 else args[0]
    return self.decorator(self, identifier, **kws)

  def _decorate_component(self, suffix, abbreviate=True):
    if abbreviate:
      return f"{self.decorate(None, hidden=True)}{suffix[0]}"
    else:
      return self.decorate(suffix)
  
  def _decorate_attribute(self, identifier):
    match identifier:
      case str(): return identifier
      case list() | tuple(): return "_".join(identifier)

  # 
  def __str__(self):
    return self.name
  
  def __setup__(self):
    super().__setup__()
    self.method_from("create")
    self.method_from("destroy")
    self.method_from("copy")
    self.method_from("equal")
    self.method_from("compare")
    self.method_from("hash")

  def __register__(self):
    # By recording the attribute names instead of real method objects makes it possible to
    # disable object emitting by setting the respective attribute to None
    # prior entering this method (__setup__ is a perfect place for this)
    self.references.update( [t for x in self.__attributes if hasattr(self, x) and not (t := getattr(self, x)) is None] )

  @property
  def rvalue_type(self):
    return self

  @property
  def lvalue_type(self):
    return self

  @property
  def in_type(self):
    return Indirection(self, constant=True)

  @property
  def out_type(self):
    return Indirection(self)

  @property
  def inout_type(self):
    return Indirection(self)

  @property
  def view_type(self):
    return Indirection(self, constant=True)


#
class _StructRenderer:

  def _render_struct(self, stream):
    if not self.public:
      stream.append("/** @internal */\n")
  
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    # Structures are expected to be rendered in the interface header
    # even for internal types since they can be a part of more acessible structures
    # treated by the public inline code
    if header:
      self._render_struct(stream)