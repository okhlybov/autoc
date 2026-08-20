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
    #case str(): return StringLiteral(obj)
    case str(): return Literal("int", obj)
  raise TypeError(f"{obj} is not convertible to Value")


#
def _parameter(obj):
  match obj:
    case Callable.Parameter(): return obj
    case _: return Callable.In(obj)


#
def _active(obj):
  match obj:
    case Callable(): return obj.active
    case _ if callable(obj): return True
  return False


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
class Type(metaclass = _MultiphaseConstructible):

  def __init__(self, visibility="public", *args, **kws):
    super().__init__(*args, **kws)
    self.visibility = visibility
    
  def __setup__(self):
    # Basic methods
    self.create = Callable(None, {"target": out(self)}, constraint=lambda: self.constructible)
    self.destroy = Callable(None, {"target": inout(self)}, constraint=lambda: self.destructible)
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


#
class Primitive(Type, _Traitful):

  def __init__(self, name, **kws):
    super().__init__(**kws)
    self.name = str(name)
    if not self.name in _type_cache:
      _type_cache[self.name] = self

  def __setup__(self):
    super().__setup__()
    self.create = Macro.of(self.create, lambda target: f"{target} = 0")
    self.copy = Macro.of(self.copy, lambda target, source: f"{target} = {source}")
    self.equal = Macro.of(self.equal, lambda left, right: f"({left} == {right})")
    self.compare = Macro.of(self.compare, lambda left, right: f"({left} == {right} ? 0 : ({left} < {right} ? -1 : +1))")
    self.hash = Macro.of(self.hash, lambda target: f"(size_t)({target})")
    
  def __str__(self):
    return self.name
  
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
  
  def __init__(self, type, name):
    super().__init__(type)
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
      
  def __str__(self):
    return (f"const {self.type}" if self.constant else str(self.type)) + "*"*self.indirection

  #
  def variable(self, name):
    return Indirection.Variable(self, name)

  class Variable(Variable):

    def __init__(self, obj, name):
    # It makes little to no sense to define variable of const type so drop constness qualifier if it is set
      super().__init__(Indirection(obj.type, indirection=obj.indirection, constant=False), name)

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
    return self

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
  
  def __init__(self, result, parameters, constraint=lambda: True, *args, **kws):
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
class _Parametrized(Callable):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self.result = None if self._result is None or self._result == "void" else _parameter(self._result).resolve(self)
    self.parameters = {str(n): _parameter(t).resolve(self) for n, t in self._parameters.items()}

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


#
class Function(_Parametrized):
  
  @classmethod
  def of(self, callable, name, constraint=None, **kws):
    return self(callable._result, name, callable._parameters, constraint=callable.constraint if not constraint else constraint, **kws)

  def __init__(self, result, name, parameters, abstract=None, *args, **kws):
    super().__init__(result, parameters, *args, **kws)
    self.name = str(name)
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