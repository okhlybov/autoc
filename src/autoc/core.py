import re
import sys
import autoc.module
from collections.abc import Iterable # substitute for missing iterable()


_type_rxcache = [] # [ (rx, type) ]
_type_cache = {} # { name: type }


def _type2type(obj):
  return obj if isinstance(obj, Type) else None


def _str2type(obj):
  if isinstance(obj, str):
    for rx, type in _type_rxcache:
      if rx.match(obj):
        _type_cache[type.name] = type
        return type
    if obj in _type_cache:
      return _type_cache[obj]
    return Primitive(obj)
  return None


#
def _type(obj):
  for c in (_type2type, _str2type):
    if x := c(obj):
      return x
  raise TypeError(f"{obj} is not convertible to Type")


#
def _value(obj):
  match obj:
    # TODO complex
    case Value(): return obj
    case int(): return Literal("int", obj)
    case float(): return Literal("double", obj)
    case str(): return Literal("int", obj) # FIXME actually this should be borrowing the target's type
  raise TypeError(f"{obj} is not convertible to Value")


#
def _parameter(obj):
  match obj:
    case Callable.Parameter(): return obj
    case _: return Callable.In(obj)


#
class _MultiphaseConstructible(type):

  def __call__(cls, *args, **kws):
    obj = super().__call__(*args, **kws)
    obj.__setup__()
    obj.__register__()
    return obj


# Mixin for types which support all operations
class _Traitful:
  
  @property
  def constructible(self):
    return True
  
  @property
  def default_constructible(self):
    return self.constructible and len(self.create.parameters) == 1

  @property
  def destructible(self):
    return True

  @property
  def copyable(self):
    return True
  
  @property
  def comparable(self):
    return True
  
  @property
  def orderable(self):
    return True
  
  @property
  def hashable(self):
    return True
  

#
class Type(autoc.module.Entity, metaclass=_MultiphaseConstructible):

  def __init__(self, *args, visibility="public", **kws):
    super().__init__(*args, **kws)
    self.visibility = visibility
    
  def __setup__(self):
    # Basic methods
    self.create = Callable(None, {"target": out(self)}, constraint=lambda: self.constructible)
    self.destroy = Callable(None, {"target": self}, constraint=lambda: self.destructible)
    self.copy = Callable(None, {"target": out(self), "source": self}, constraint=lambda: self.copyable)
    self.equal = Callable("int", {"left": self, "right": self}, constraint=lambda: self.comparable)
    self.compare = Callable("int", {"left": self, "right": self}, constraint=lambda: self.orderable)
    self.hash = Callable("size_t", {"target": self}, constraint=lambda: self.hashable)
    # Methods used by the hash-based containers
    self.hash_lookup_hash = lambda *args: self.hash(*args)
    self.hash_lookup_equal = lambda *args: self.equal(*args)
  
  def __register__(self): pass
  
  @property
  def public(self):
    return self.visibility == "public"
  
  @property
  def private(self):
    return self.visibility == "private"

  @property
  def internal(self):
    return self.visibility == "internal"

  def variable(self, name):
    return Variable(self, name)


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


# Global decorator used by all named type descentants unless overridden locally
decorator = camel_decorator


# Mixin for named types which can have methods/components/attributes etc.
class _Named(Type):
  
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
  
  def __register__(self):
    # By recording the attribute names instead of real method objects makes it possible to
    # disable object emitting by setting the respective attribute to None
    # prior entering this method (__setup__ is a perfect place for this)
    self.references.update( [t for x in self.__attributes if hasattr(self, x) and not (t := getattr(self, x)) is None] )


#
class Primitive(_Named, _Traitful):

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    if not self.name in _type_cache:
      _type_cache[self.name] = self

  def __setup__(self):
    super().__setup__()
    self.macro_from("create", lambda target: f"{target} = 0")
    self.macro_from("copy", lambda target, source: f"{target} = {source}")
    self.macro_from("equal", lambda left, right: f"({left} == {right})")
    self.macro_from("compare", lambda left, right: f"({left} == {right} ? 0 : ({left} < {right} ? -1 : +1))")
    self.macro_from("hash", lambda target: f"(size_t)({target})")
    
  @property
  def destructible(self):
    return False # Primitive type almost always bears no destructor

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
    return Indirection(self)

  @property
  def inout_type(self):
    return Indirection(self)

  @property
  def view_type(self):
    return Indirection(self, constant=True)


#
class Composite(_Named, _Traitful):

  def __setup__(self):
    super().__setup__()
    self.method_from("create")
    self.method_from("destroy")
    self.method_from("copy")
    self.method_from("equal")
    self.method_from("compare")
    self.method_from("hash")

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


# Abstract class for renderable contents, basically a str-like type
class Statement:

  def __init__(self, contents, *args, **kws):
    super().__init__(*args, **kws)
    self.contents = str(contents)

  def __str__(self):
    return self.contents


def _indirection(obj):
  return t.indirection if isinstance(t := _type(obj), Indirection) else 0


def _indifference(lt, rt):
  return _indirection(lt) - _indirection(rt)


# Abstract class representing a typed value of unspecified contents which can be passed to callable
class Value:
  
  def __init__(self, type, *args, **kws):
    super().__init__(*args, **kws)
    self.type = _type(type)

  def bind(self, type):
    if (i := _indifference(self.type, type)) < 0:
      raise ValueError(f"can not dereference value {self} with & operator")
    return "*"*i


# Class representing a typed value with generic renderable contents
class Expression(Value, Statement):

  def bind(self, type):
    return super().bind(type) + self.contents


#
class Literal(Expression):
  
  def bind(self, type):
    return self.contents


#
def string(value):
  return StringLiteral(value)


#
class StringLiteral(Literal):

  def __init__(self, value, *args, **kws):
    super().__init__(Indirection("char", constant=True), f"\"{value}\"")


#
def char(obj):
  return CharacterLiteral(obj)


#
class CharacterLiteral(Literal):

  def __init__(self, value, *args, **kws):
    super().__init__("char", f"'{str(value)[0]}'")


# Class for representing the C variable
class Variable(Value):
  
  def __init__(self, type, name, **kws):
    super().__init__(type, **kws)
    self.name = str(name)

  def bind(self, type):
    i = _indifference(self.type, type)
    if i < -1:
      raise ValueError(f"too many & addressing operations requested for {self}")
    return f"&{self.name}" if i == -1 else "*"*i + self.name
    
  @property
  def definition(self):
    return f"{self.type} {self.name}"
  
  def __str__(self):
    return self.name
  

#
class Indirection(Type):

  def __init__(self, type, *args, indirection=1, constant=None, **kws):
    super().__init__(*args, **kws)
    if isinstance(t := _type(type), Indirection):
      self.type = t.type
      self.indirection = indirection + t.indirection
      self.constant = t.constant if constant is None else constant
    else:
      self.type = t
      self.indirection = indirection
      self.constant = True if constant is True else False
    self.dependencies.add(self.type)
      
  def __str__(self):
    return (f"const {self.type}" if self.constant else str(self.type)) + "*"*self.indirection

  #
  def constness(self, value):
    return Indirection(self.type, indirection=self.indirection, constant=value)
  
  #
  def variable(self, name):
    return Indirection.Variable(self, name)

  class Variable(Variable):

    def __init__(self, obj, name):
    # It makes little to no sense to define variable of const type so drop constness qualifier if it is set
      super().__init__(obj.constness(False), name)

    @property
    def definition(self):
      return f"{super().definition} = 0"
  
  @property
  def rvalue_type(self):
    return self.type

  @property
  def lvalue_type(self):
    return self.type

  @property
  def in_type(self):
    return Indirection(self.type, constant=True)

  @property
  def out_type(self):
    return Indirection(self.type, indirection=2)

  @property
  def inout_type(self):
    return self


#
def out(obj):
  return Callable.Out(obj)


#
def inout(obj):
  return Callable.InOut(obj)


# Basic callable descriptor
class Callable:
  
  def __init__(self, result, parameters, *args, constraint=lambda: True, **kws):
    super().__init__(*args, **kws)
    # Capture raw parameter description to be used in modeling of the descendant types
    self._result = result
    self._parameters = parameters
    self.constraint = constraint
    
  @property
  def active(self):
    return self.constraint() is True

  @property
  def _result_c(self):
    return "void" if self.result is None else str(self.result)

  @property
  def signature(self):
    return "%s(%s)" % (self._result_c, ", ".join(str(t) for t in self.parameters.values()))

  def contents(self, contents):
    if self.result is None:
      return Statement(contents)
    else:
      return Expression(self.result, contents)

  class Parameter:
    def __init__(self, type):
      self.type = _type(type)
    def resolve(self, callable):
      return self.type
      
      
  class In(Parameter):
    def resolve(self, callable):
      return callable.resolve_in(self.type)
    
  class Out(Parameter):
    def resolve(self, callable):
      return callable.resolve_out(self.type)
  
  class InOut(Parameter):
    def resolve(self, callable):
      return callable.resolve_inout(self.type)


#
class _Parametrized(Callable, autoc.module.Entity):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self.result = None if self._result is None or self._result == "void" else _parameter(self._result).resolve(self)
    self.parameters = {str(n): _parameter(t).resolve(self) for n, t in self._parameters.items()}
    self.dependencies.update(self.parameters.values())
    if not self.result is None:
      self.dependencies.add(self.result)

  def __call__(self, *arguments):
    if not self.active:
      raise ValueError(f"attempt to call disabled function {self}")
    if (na := len(arguments)) != (np := len(self.parameters)):
      raise TypeError(f"{self} takes {np} parameter(s) but {na} given")
    return [_value(argument).bind(type) for argument, type in zip(arguments, self.parameters.values())]


#  
class Macro(_Parametrized):
  
  @classmethod
  def of(self, callable, emitter, constraint=None, **kws):
    return self(callable._result, callable._parameters, emitter, constraint=callable.constraint if not constraint else constraint, **kws)
  
  def __init__(self, result, parameters, emitter, **kws):
    super().__init__(result, parameters, **kws)
    self.emitter = emitter

 
  def resolve_in(self, type):
    return type.rvalue_type
  
  def resolve_out(self, type):
    return type.lvalue_type
  
  def resolve_inout(self, type):
    return type.lvalue_type

  def __call__(self, *arguments):
    return self.contents(self.emitter(*super().__call__(*arguments)))
  
  def __str__(self):
    return "->"


#
class Function(_Parametrized):
  
  @classmethod
  def of(self, callable, name, constraint=None, **kws):
    return self(callable._result, name, callable._parameters, constraint=callable.constraint if not constraint else constraint, **kws)

  def __init__(self, result, name, parameters, visibility="public", linkage="external", abstract=None, dependencies=(), **kws):
    super().__init__(result, parameters, dependencies=(*dependencies, _linkage_code), **kws)
    self.name = str(name)
    self.linkage = linkage
    self.visibility = visibility
    self.__abstract = abstract
    self.arguments = [Variable(t, n) for n, t in self.parameters.items()] # Local variables deduced from function's formal parameters
    for x in self.arguments:
      setattr(self, x.name, x)

  def resolve_in(self, type):
    return type.in_type
  
  def resolve_out(self, type):
    return type.out_type
  
  def resolve_inout(self, type):
    return type.inout_type

  def __call__(self, *arguments):
    return self.contents(f"{self.name}(" + ", ".join(super().__call__(*arguments)) + ")")

  def __str__(self):
    return self.name

  def __repr__(self):
    return f"{self.name} {super().__repr__()}"

  @property
  def abstract(self):
    return not hasattr(self, "code") if self.__abstract is None else self.__abstract is True

  def _declaration_c(self, render_names):
    if render_names:
      return "%s %s(%s)" % (self._result_c, self.name, ", ".join(f"{t} {n}" for n, t in self.parameters.items()))
    else:
      return "%s %s(%s)" % (self._result_c, self.name, ", ".join(str(t) for t in self.parameters.values()))

  @property
  def _body_c(self):
    if self.abstract:
      raise ValueError(f"attempt to render definition for abstract function {self}")
    if not hasattr(self, "code"):
      raise ValueError(f"missing body of non-abstract function {self}")
    match self.code:
      case Iterable(): cs = [str(x) for x in self.code]
      case _ if callable(self.code): cs = [str(self.code())]
      case _: cs = [str(self.code)]
    return str().join(("{", *cs, "}"))

  @property
  def declaration(self):
    return self._declaration_c(False)

  @property
  def definition(self):
    return self._declaration_c(True) + self._body_c

  def __enter__(self):
    return self
  
  def __exit__(self, *args):
    return False

  def __inline_code(self, obj):
    self.linkage = "inline"
    self.code = obj
    
  inline_code = property(fset=__inline_code)
  
  def __external_code(self, obj):
    self.linkage = "external"
    self.code = obj

  external_code = property(fset=__external_code)
  
  @property
  def external(self):
    return self.linkage == "external"

  @property
  def inline(self):
    return self.linkage == "inline"

  @property
  def public(self):
    return self.visibility == "public"

  @property
  def private(self):
    return self.visibility == "private"

  @property
  def internal(self):
    return self.visibility == "internal"

  @property
  def declaration(self):
    return self._declaration_c(self.public)
  
  #
  def render_declarations(self, stream, header):
    if self.active:
      super().render_declarations(stream, header)
      if (header and not self.internal) or (not header and self.internal):
        self._render_declaration(stream)

  #
  def render_definitions(self, stream, header):
    if self.active:
      super().render_definitions(stream, header)
      if self.inline:
        if (header and not self.internal) or (not header and self.internal):
          self._render_definition(stream)
      else:
        if not header:
          self._render_definition(stream)

  #  
  def _render_definition(self, stream):
    if not self.abstract:
      stream.append(self.definition)

  #
  def _render_declaration(self, stream):
    if not self.internal:
      self._render_description(stream)
    self._render_decorator(stream)
    stream.append(self.declaration)
    stream.append(";\n")

  #
  def _render_description(self, stream):
    if self.public:
      stream.append("/* @public */\n")
    elif not self.internal:
      stream.append("/* @private */\n")

  #
  def _render_decorator(self, stream):
    stream.append(_linkage_spec_c[self.linkage])


_linkage_spec_c = {"external": "AUTOC_EXTERN ", "inline": "AUTOC_STATIC_INLINE "}


_linkage_code = autoc.module.Code(interface="""
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
""")
