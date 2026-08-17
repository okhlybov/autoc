import re


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
  for c in [_type2type, _str2type]:
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
    case str(): return StringLiteral(obj)
  raise TypeError(f"{obj} is not convertible to Value")


#
def _parameter(obj):
  match obj:
    case Callable.Parameter(): return obj
    case _: return Callable.In(obj)


class _MultiphaseConstructible(type):

  def __call__(cls, *args, **kws):
    obj = super().__call__(*args, **kws)
    obj.__setup__()
    return obj


#
class Type(metaclass = _MultiphaseConstructible):

  def __setup__(self):
    self.create = Callable(None, {"target": out(self)})
    self.destroy = Callable(None, {"target": inout(self)})
    self.copy = Callable(None, {"target": out(self), "source": self})
    self.compare = Callable("int", {"left": self, "right": self})
    self.order = Callable("int", {"left": self, "right": self})
    self.hash = Callable("size_t", {"target": self})
  
  @property
  def constructible(self):
    return callable(self.create)
  
  @property
  def default_constructible(self):
    return self.constructible and len(self.create.parameters) == 1

  @property
  def destructible(self):
    return callable(self.destroy)

  @property
  def copyable(self):
    return callable(self.copy)
  
  @property
  def comparable(self):
    return callable(self.compare)
  
  @property
  def orderable(self):
    return callable(self.order)
  
  @property
  def hashable(self):
    return self.comparable and callable(self.hash)
  
  def variable(self, name):
    return Variable(self, name)


#
class Primitive(Type):

  def __init__(self, name, **kws):
    super().__init__(**kws)
    self.name = str(name)
    if not self.name in _type_cache:
      _type_cache[self.name] = self

  def __setup__(self):
    super().__setup__()
    self.create = Macro.of(self.create, lambda target: f"{target} = 0")
    self.copy = Macro.of(self.copy, lambda target, source: f"{target} = {source}")
    self.compare = Macro.of(self.compare, lambda left, right: f"{left} == {right}")
    self.order = Macro.of(self.order, lambda left, right: f"{left} == {right} ? 0 : ({left} < {right} ? -1 : +1)")
    self.hash = Macro.of(self.hash, lambda target: f"(size_t)({target})")
    
  def __str__(self):
    return self.name
  
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


#
class Composite(Type):

  def __init__(self, name, **kws):
    super().__init__(**kws)
    self.name = str(name)

  def __str__(self):
    return self.name
  
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


#
class Indirection(Type):

  def __init__(self, type, indirection=1, constant=None, **kws):
    super().__init__(**kws)
    if isinstance(t := _type(type), Indirection):
      self.type = t.type
      self.indirection = indirection + t.indirection
      self.constant = t.constant if constant is None else constant
    else:
      self.type = t
      self.indirection = indirection
      self.constant = True if constant is True else False
      
  def __str__(self):
    return (f"const {self.type}" if self.constant else str(self.type)) + "*"*self.indirection
  

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
Literal = Expression


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
  
  def __init__(self, type, name):
    super().__init__(type)
    self.name = str(name)

  def bind(self, type):
    i = _indifference(self.type, type)
    if i < -1:
      raise ValueError(f"too many & addressing operations requested for {self}")
    return f"&{self.name}" if i == -1 else "*"*i + self.name
    
  @property
  def declaration(self):
    return f"{self.type} {self.name}"

#
def out(obj):
  return Callable.Out(obj)


#
def inout(obj):
  return Callable.InOut(obj)


# Basic callable descriptor
class Callable:
  
  def __init__(self, result, parameters):
    # Capture raw parameter description to be used in modeling of the descendant types
    self._result = result
    self._parameters = parameters
    
  @property
  def result_c(self):
    return "void" if self.result is None else str(self.result)

  @property
  def signature(self):
    return "%s(%s)" % (self.result_c, ", ".join(str(t) for t in self.parameters.values()))

  def contents(self, contents):
    if self.result is None:
      return Statement(contents)
    else:
      return Expression(self.result, contents)

  class Parameter:
    def __init__(self, type):
      self.type = _type(type)
      
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
class Parametrized(Callable):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self.result = None if self._result is None or self._result == "void" else _parameter(self._result).resolve(self)
    self.parameters = {str(n): _parameter(t).resolve(self) for n, t in self._parameters.items()}

  def __call__(self, *arguments):
    if (na := len(arguments)) != (np := len(self.parameters)):
      raise TypeError(f"{self} takes {np} parameter(s) but {na} given")
    return [_value(argument).bind(type) for argument, type in zip(arguments, self.parameters.values())]


#  
class Macro(Parametrized):
  
  @classmethod
  def of(self, callable, emitter, **kws):
    return Macro(callable._result, callable._parameters, emitter, **kws)
  
  def __init__(self, result, parameters, emitter, **kws):
    super().__init__(result, parameters, **kws)
    self.emitter = emitter

 
  def resolve_in(self, type):
    return type.rvalue_type
  
  def resolve_out(self, type):
    return type.lvalue_type
  
  def resolve_inout(self, type):
    return type.rvalue_type

  def __call__(self, *arguments):
    return self.contents(self.emitter(*super().__call__(*arguments)))
  
#
class Functional(Parametrized):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self.arguments = [Variable(t, n) for n, t in self.parameters.items()] # Local variables deduced from function's formal parameters

  def resolve_in(self, type):
    return type.in_type
  
  def resolve_out(self, type):
    return type.out_type
  
  def resolve_inout(self, type):
    return type.inout_type


#
class Function(Functional):
  
  @classmethod
  def of(self, callable, name, **kws):
    return Function(callable._result, name, callable._parameters, **kws)

  def __init__(self, result, name, parameters, **kws):
    super().__init__(result, parameters, **kws)
    self.name = str(name)

  def __call__(self, *arguments):
    return self.contents(f"{self.name}(" + ", ".join(super().__call__(*arguments)) + ")")

  @property
  def declaration(self):
    return "%s %s(%s)" % (self.result_c, self.name, ", ".join(str(t) for t in self.parameters.values()))