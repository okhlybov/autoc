#
def _type(obj):
  match obj:
    case Type(): return obj
    case str(): return Primitive(obj)
  raise TypeError(f"{obj} is not convertible to Type")


#
def _value(obj):
  match obj:
    case Value(): return obj
  raise TypeError(f"{obj} is not convertible to Value")


#
def _parameter(obj):
  match obj:
    case Callable.Parameter(): return obj
    case _: return Callable.In(obj)

  
#
class Type:

  def variable(self, name):
    return Variable(self, name)


#
class Primitive(Type):

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
    return (f"const {self.type}" if self.constant else str(self.type)) + '*'*self.indirection
  

#
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


# Class representing a typed value of unspecified contents which can be passed to callable
class Value:
  
  def __init__(self, type, *args, **kws):
    super().__init__(*args, **kws)
    self.type = _type(type)

  def bind(self, type):
    if (i := _indifference(self.type, type)) < 0:
      raise ValueError(f"can not take address of {self} with & operator")
    return "*"*i


# Class representing a typed value with renderable contents
class Expression(Value, Statement):

  def bind(self, type):
    return super().bind(type) + self.contents


#
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
  def declaration_c(self):
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
    self.result = None if result is None or result == "void" else _type(result)
    self._parameters = parameters # Capture raw parameter description to be used in modeling of the descendant types
    
  @property
  def result_c(self):
    return "void" if self.result is None else str(self.result)

  @property
  def signature_c(self):
    return "%s(%s)" % (self.result_c, ", ".join(str(t) for t in self.parameters.values()))

  def _cast(self, contents):
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
    self.parameters = {str(n): _parameter(t).resolve(self) for n, t in self._parameters.items()}
  
#  
class Macro(Parametrized):
  
  @classmethod
  def of(self, callable, emitter, **kws):
    return Macro(callable.result, callable._parameters, emitter, **kws)
  
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
    return self._cast("z")
  
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
    return Function(callable.result, name, callable._parameters, **kws)

  def __init__(self, result, name, parameters, **kws):
    super().__init__(result, parameters, **kws)
    self.name = str(name)
    
  @property
  def declaration_c(self):
    return "%s %s(%s)" % (self.result_c, self.name, ", ".join(str(t) for t in self.parameters.values()))