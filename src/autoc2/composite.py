import re
import sys
import autoc2.std as std
from autoc2.core import Type, Indirection, out, inout
from autoc.module import Entity


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
class Composite(Type, Entity):

  
  def __init__(self, name, prefix=None, decorator=None, visibility="public", *args, **kws):
    super().__init__(**kws)
    self.name = str(name)
    self.prefix = prefix if prefix else self.name
    self.visibility = visibility
    self.decorator = decorator if decorator else sys.modules[__name__].decorator
    self.__methods = set()

  def method(self, result, identifier, parameters, visibility=None, linkage="external", hidden=False, dependencies=tuple(), attribute=None, function=std.Function, **kws):
    if not visibility: visibility = self.visibility
    m = function(result, self.decorate(identifier, hidden=hidden), parameters, dependencies=(self, *dependencies), visibility=visibility, linkage=linkage)
    x = self._decorate_attribute(attribute if attribute else identifier)
    self.__methods.add(x) # Record attribute name which holds the method object
    setattr(self, x, m)
    return m
  
  def method_of(self, identifier, attribute=None, **kws):
    x = self._decorate_attribute(attribute if attribute else identifier)
    m = getattr(self, x)
    self.__methods.discard(x)
    delattr(self, x)
    return self.method(m._result, x, m._parameters, **kws)
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

  def __str__(self):
    return self.name
  
  def __setup__(self):
    super().__setup__()
    self.method_of("create")
    self.method_of("destroy")
    self.method_of("copy")
    self.method_of("equal")
    self.method_of("compare")
    self.method_of("hash")

  def __register__(self):
    # By recording the attribute names instead of real method objects makes it possible to
    # disable object emitting by setting the respective attribute to None
    # prior entering this method (__setup__ is a perfect place for this)
    self.references.update([t for x in self.__methods if (t := getattr(self, x))])

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