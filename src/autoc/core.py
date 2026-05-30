from enum import Enum, auto
from collections.abc import Iterable


_type_cache = [] # [ (matcher, type) ]


def __pointer2type(obj):
  if isinstance(obj, Pointer):
    if obj.indirection == 0:
      return obj.base
    else:
      return obj
  return None


def __type2type(obj):
  return obj if isinstance(obj, Type) else None


def __str2type(obj):
  if isinstance(obj, str):
    for rx, type in _type_cache:
      if rx.match(str(obj)):
        return type
    return Primitive(obj)
  return None


_type_converters = [__type2type, __str2type, __pointer2type]


#
def _type(obj):
  for c in _type_converters:
    if x := c(obj):
      return x
  raise TypeError(f"can not construct a Type from {obj}")


#
def _value(obj):
  match obj:
    case Value(): return obj
    case int(): return Literal("int", obj)
    case float(): return Literal("double", obj)
    case str(): return Verbatim(obj)
  raise TypeError(f"can not construct a Value from {obj}")
  

#
def _parameter(obj):
  match obj:
    case Callable.Parameter(): return obj
    case Type() | str(): return Callable.In(obj)
  raise TypeError(f"can not construct a callable Parameter from {obj}")


#  
def string(obj):
  return StrLiteral(obj)


#
def char(obj):
  return CharLiteral(obj)


#
def out(obj):
  return Callable.Out(obj)


#
def inout(obj):
  return Callable.InOut(obj)


# Generic identifier's visibility
class Visibility(Enum):
  PUBLIC = auto()
  PRIVATE = auto()
  INTERNAL = auto()


#
class Value:
  
  def __init__(self, type, *args, **kws):
    super().__init__(*args, **kws)
    self.type = None if type is None else _type(type)

  def bind(self, type):
    x = self.type.indirection - type.indirection
    if x >= 0:
      return "*"*x + str(self)
    raise ValueError(f"can not take address of the value {self} with &")


#
class Variable(Value):
  def __init__(self, type, name, *args, **kws):
    super().__init__(type, *args, **kws)
    self.name = str(name)

  def __str__(self): return self.name

  def __repr__(self): return f"{repr(self.name)} :: {repr(self.type)}"

  def bind(self, type):
    x = self.type.indirection - type.indirection
    if x >= 0:
      return "*"*x + str(self)
    elif x == -1:
      return "&" + str(self)
    raise ValueError(f"bad indirection level {x} for taking address of {self} with &")

  @property
  def definition(self):
    return f"{self.type} {self.name}"


# Class defining the call interface
class Signature:
  
  def __init__(self, result, parameters, constraint=lambda: True):
    self.result = result
    self.parameters = parameters
    self.constraint = constraint


# Abstract callable with return type and input parameters
class Callable:
  
  #
  def __init__(self, result, parameters, constraint=lambda: True, *args, **kws):
    super().__init__(*args, **kws)
    self.parameters = {str(name): _parameter(type) for name, type in parameters.items()}
    self.types = [parameter.forward_type(self) for parameter in self.parameters.values()]
    self.arguments = [Variable(type, name) for type, name in zip(self.types, self.parameters.keys())]
    for x in self.arguments:
      setattr(self, x.name, x)
    self.constraint = constraint
    self.__result = result

  @property      
  def result(self):
    r = self.__result
    return _type(r) if not (r is None or r == "void") else None
    # Got to use property instead of attibute to avoid infinite recursion

  @property
  def _result_c(self):
    return "void" if self.result is None else str(self.result)
    
  #
  @property
  def signature(self):
    return "%s(%s)" % (self._result_c, ", ".join([str(x) for x in self.types]))
  
  # Construct a C function type definition out of the callable signature
  def _typedef(self, name):
    return "%s (*%s)(%s)" % (self._result_c, name, ", ".join([str(x) for x in self.types]))
  
  class Parameter:
    def __init__(self, type):
      self.type = _type(type)
      
  class In(Parameter):
    def forward_type(self, type):
      return type.type_in(self.type)
  
  class Out(Parameter):
    def forward_type(self, type):
      return type.type_out(self.type)

  class InOut(Parameter):
    def forward_type(self, type):
      return type.type_inout(self.type)

  class Call(Value):
    
    def __init__(self, callable, arguments, *args, **kws):
      super().__init__(callable.result, *args, **kws)
      self.callable = callable
      nargs = len(arguments)
      nparams = len(self.callable.types)
      if not (nargs == nparams):
        raise ValueError(f"callable {callable.signature} takes {nparams} arguments but {nargs} given")
      self.arguments = [_value(x) for x in arguments]

    def __call__(self, *arguments):
      return self.type(self, *arguments)


# C code injector
class Macro(Callable):

  #
  def __init__(self, result, parameters, emitter, constraint=lambda: True, *args, **kws):
    super().__init__(result, parameters, constraint=constraint, *args, **kws)
    self.emitter = emitter

  @classmethod
  def implement(self, signature, emitter, *args, **kws):
    return Macro(signature.result, signature.parameters, emitter, *args, constraint=signature.constraint, **kws)

  def type_in(self, type):
    return type.rvalue_type

  def type_out(self, type):
    return type.lvalue_type

  def type_inout(self, type):
    return type.rvalue_type

  #
  def __call__(self, *arguments):
    return Macro.Call(self, arguments)
    
  class Call(Callable.Call):
    def __str__(self):
      return self.callable.emitter(*[value.bind(type) for type, value in zip(self.callable.types, self.arguments)])


# Anonymous C function with no body, only the callable signature
# Suitable for handling C function pointers
class Functional(Callable):

  def type_in(self, type):
    return type.in_type

  def type_out(self, type):
    return type.out_type
  
  def type_inout(self, type):
    return type.inout_type
  
  #
  def __call__(self, *arguments):
    return Functional.Call(self, arguments)

  class Call(Callable.Call):
    def __str__(self):
      return "(%s)" % (", ".join([value.bind(type) for type, value in zip(self.callable.types, self.arguments)]))


# Regular C function with body
class Function(Functional):

  #
  def __init__(self, result, name, parameters, code=None, *args, **kws):
    super().__init__(result, parameters, *args, **kws)
    self.name = str(name)
    self.code = code

  #
  def __call__(self, *arguments):
    return Function.Call(self, arguments)

  #
  def __str__(self):
    return self.name
    
  #
  @property
  def declaration(self):
    return "%s %s(%s)" % (self._result_c, self.name, ", ".join([f"{x.type} {x.name}" for x in self.arguments]))

  #
  @property
  def definition(self):
    if not isinstance(self.code, str) and not self.code:
      raise ValueError(f"missing body of non-abstract function {self.name}()")
    match self.code:
      case Iterable(): cs = [str(x) for x in self.code]
      case _ if callable(self.code): cs = [str(self.code())]
      case _: cs = [str(self.code)]
    return str().join([self.declaration, "{", *cs, "}\n"])
    
  class Call(Functional.Call):
    def __str__(self):
      return "%s%s" % (self.callable.name, super().__str__())


#
class __Constructor(type):
  def __call__(cls, *args, **kws):
    obj = super().__call__(*args, **kws)
    obj.__setup__()
    obj.__register__()
    return obj


#
class Type(metaclass = __Constructor):
  
  def __init__(self, name, visibility="PUBLIC", *args, **kws):
    super().__init__(*args, **kws)
    self.name = str(name)
    self.indirection = 0
    self.visibility = visibility if isinstance(visibility, Visibility) else Visibility[visibility]

  def __str__(self):
    return self.name

  def __repr__(self):
    return f"{self} {super().__repr__()}"

  def __setup__(self):
    self.create = Signature(None, {"target": out(self)}, constraint=lambda: self.constructible)
    self.destroy = Signature(None, {"target": inout(self)}, constraint=lambda: self.destructible)
    self.copy = Signature(None, {"target": out(self), "source": self}, constraint=lambda: self.copyable)
    self.equal = Signature("int", {"left": self, "right": self}, constraint=lambda: self.comparable)
    self.hash = Signature("size_t", {"target": self}, constraint=lambda: self.hashable)
    self.compare = Signature("int", {"left": self, "right": self}, constraint=lambda: self.orderable)
    # Used by the lookup mechanisms of hash-based containers
    self._lookup_hash = Macro.implement(self.hash, lambda target: str(self.hash(target)))
    self._lookup_equal = Macro.implement(self.equal, lambda left, right: str(self.equal(left, right)))

  def __register__(self):
    pass
  
  def as_macro(self, slot, emitter, *args, **kws):
    s = getattr(self, slot)
    m = Macro(s.result, s.parameters, emitter, *args, constraint=s.constraint, **kws)
    setattr(self, slot, m)
    return m

  #
  def variable(self, name):
    return Variable(self, name)

  #
  @property
  def public(self):
    return self.visibility is Visibility.PUBLIC
  
  #
  @property
  def private(self):
    return self.visibility is Visibility.PRIVATE
  
  #
  @property
  def internal(self):
    return self.visibility is Visibility.INTERNAL
  
  @property
  def constructible(self):
    return hasattr(self, "create") and len(self.create.arguments) == 1 # Method has no custom parameters past target object

  @property
  def emplaceable(self):
    return hasattr(self, "create") and len(self.create.arguments) >= 1 # Mathod is assumed to have at least one parameter, the target object, followed by arbitrary number of custom parameters
  
  @property
  def destructible(self):
    return hasattr(self, "destroy")

  @property
  def copyable(self):
    return hasattr(self, "copy")

  @property
  def comparable(self):
    return hasattr(self, "equal")

  @property
  def hashable(self):
    return hasattr(self, "hash")

  @property
  def orderable(self):
    return hasattr(self, "compare")


#
class Primitive(Type):
  
  def __setup__(self):
    super().__setup__()
    self.as_macro("create", lambda target: f"{target} = 0")
    self.as_macro("copy", lambda target, source: f"{target} = {source}")
    self.as_macro("equal", lambda left, right: f"({left} == {right})")
    self.as_macro("hash", lambda target: f"(size_t)({target})")
    self.as_macro("compare", lambda left, right: f"({left} == {right} ? 0 : ({left} < {right} ? -1 : +1))")

  @property
  def destructible(self):
    return False

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
    return Pointer(self)


#
class Pointer(Primitive):
  
  def __init__(self, type, *args, indirection=1, constant=False, **kws):
    i = indirection
    t = _type(type)
    if isinstance(t, Pointer):
      i += t.indirection
      t = t.base
    signature = "const " if constant else str()
    signature += t.name + "*"*i
    super().__init__(signature, *args, **kws)
    self.base = t
    self.indirection = i
    self.constant = constant

  @property
  def in_type(self):
    return Pointer(self.base, constant=True)
    
  @property
  def out_type(self):
    return Pointer(self)

  @property
  def inout_type(self):
    return self
  
  def as_const(self):
    return Pointer(self.base, indirection=self.indirection, constant=True)


#
class Verbatim(str):

  def bind(self, type):
    return self


#
class Literal(Value):
  
  def __init__(self, type, value, *args, **kws):
    super().__init__(type, *args, **kws)
    self.value = value

  def __str__(self):
    return str(self.value)
  
  
#
class StrLiteral(Literal):
  
  type = Pointer("char")
  
  def __init__(self, value, *args, **kws):
    super().__init__(StrLiteral.type, str(value), *args, **kws)
    
  def __str__(self):
    return f'"{self.value}"'
  
  
#
class CharLiteral(Literal):
  
  def __init__(self, value, *args, **kws):
    super().__init__("char", str(value)[0], *args, **kws)
    
  def __str__(self):
    return f"'{self.value}'"

 
#
class Traitless:
  @property
  def constructible(self):
    return False
  @property
  def copyable(self):
    return False
  @property
  def orderable(self):
    return False
  @property
  def comparable(self):
    return False
  @property
  def destructible(self):
    return False
  @property
  def hashable(self):
    return False