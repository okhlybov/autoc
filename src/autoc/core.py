from enum import Enum, auto


_type_cache = [] # [ (matcher, type) ]


#
def _type(obj):
  if isinstance(obj, Pointer):
    if obj.indirection == 0:
      return obj.base
    else:
      return obj
  if isinstance(obj, Type):
    return obj
  if isinstance(obj, str):
    for rx, type in _type_cache:
      if rx.match(str(obj)):
        return type
    return Primitive(obj)
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
def string(obj): return StrLiteral(obj)


#
def char(obj): return CharLiteral(obj)


#
def out(obj): return Callable.Out(obj)


#
def inout(obj): return Callable.InOut(obj)


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

#
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
  def _result_c(self): return "void" if self.result is None else str(self.result)
    
  #
  @property
  def signature(self): return "%s(%s)" % (self._result_c, ", ".join([str(x) for x in self.types]))
  
  class Parameter:
    def __init__(self, type):
      self.type = _type(type)
      
  class In(Parameter):
    def forward_type(self, type): return type.type_in(self.type)
  
  class Out(Parameter):
    def forward_type(self, type): return type.type_out(self.type)

  class InOut(Parameter):
    def forward_type(self, type): return type.type_inout(self.type)

  class Call(Value):
    def __init__(self, callable, arguments, *args, **kws):
      super().__init__(callable.result, *args, **kws)
      self.callable = callable
      nargs = len(arguments)
      nparams = len(self.callable.types)
      if not (nargs == nparams):
        raise ValueError(f"callable takes {nparams} arguments but {nargs} given")
      self.arguments = [_value(x) for x in arguments]


#
class Macro(Callable):

  #
  def __init__(self, result, parameters, emitter, constraint=lambda: True, *args, **kws):
    super().__init__(result, parameters, constraint=constraint, *args, **kws)
    self.emitter = emitter

  def type_in(self, type): return type.rvalue_type

  def type_out(self, type): return type.lvalue_type

  def type_inout(self, type): return type.rvalue_type

  #
  def __call__(self, *arguments): return Macro.Call(self, arguments)
    
  class Call(Callable.Call):
    def __str__(self):
      return self.callable.emitter(*[value.bind(type) for type, value in zip(self.callable.types, self.arguments)])


#
class Function(Callable):

  #
  def __init__(self, result, name, parameters, code=None, *args, **kws):
    super().__init__(result, parameters, *args, **kws)
    self.name = str(name)
    self.code = code

  def type_in(self, type): return type.in_type

  def type_out(self, type): return type.out_type
  
  def type_inout(self, type): return type.inout_type

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
      raise ValueError(f"missing body for non-abstract function {self.name}()")
    return str().join([self.declaration, "{", *[str(c) for c in self.code], "}\n"])
    
  class Call(Callable.Call):
    def __str__(self):
      return "%s(%s)" % (self.callable.name, ", ".join([value.bind(type) for type, value in zip(self.callable.types, self.arguments)]))


#
class _DoubleStepConstructor(type):
  def __call__(cls, *args, **kws):
    obj = super().__call__(*args, **kws)
    obj.__setup__()
    return obj


#
class Type(metaclass = _DoubleStepConstructor):
  
  def __init__(self, name, visibility="PUBLIC", *args, **kws):
    super().__init__(*args, **kws)
    self.name = str(name)
    self.indirection = 0
    self.visibility = visibility if isinstance(visibility, Visibility) else Visibility[visibility]

  def __str__(self): return self.name

  def __repr__(self): return f"{self} {super().__repr__()}"

  def __setup__(self):
    self.create = self._create(None, {"target": out(self)}, constraint=lambda: self.constructible)
    self.destroy = self._destroy(None, {"target": inout(self)}, constraint=lambda: self.destructible)
    self.copy = self._copy(None, {"target": out(self), "source": self}, constraint=lambda: self.copyable)
    self.equal = self._equal("int", {"left": self, "right": self}, constraint=lambda: self.comparable)
    self.hash = self._hash("size_t", {"target": self}, constraint=lambda: self.hashable)
    self.compare = self._compare("int", {"left": self, "right": self}, constraint=lambda: self.orderable)

    # Used by the lookup mechanisms if hash-based containers
    self._lookup_hash = self.hash
    self._lookup_equal = self.equal
    
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


#
class Primitive(Type):
  
  @property
  def constructible(self):
    return True
  
  def _create(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target: f"{target} = 0", **kws)

  @property
  def copyable(self):
    return True
  
  def _copy(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  @property
  def comparable(self):
    return True
  
  def _equal(self, result, parameters, **kws):
    return Macro(result, parameters, lambda left, right: f"({left} == {right})", **kws)

  @property
  def orderable(self):
    return True
  
  def _compare(self, result, parameters, **kws):
    return Macro(result, parameters, lambda left, right: f"({left} == {right} ? 0 : ({left} < {right} ? -1 : +1))", **kws)

  @property
  def hashable(self):
    return True
  
  def _hash(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target: f"(size_t)({target})", **kws)

  @property
  def destructible(self):
    return False
  
  def _destroy(self, result, parameters, **kws): pass
  
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
  def out_type(self):
    return Pointer(self)

  @property
  def inout_type(self):
    return self


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
class _NoTraits:
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