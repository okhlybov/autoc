#
def _type(obj):
  match obj:
    case Type(): return obj
    case str(): return Primitive(obj)
  raise f"{obj} is not convertable to Type"


#
def _value(obj):
  match obj:
    case Value(): return obj
  raise f"{obj} is not convertable to Value"


#
def _parameter(obj):
  match obj:
    case Callable.Parameter(): return obj
    case _: return Callable.In(obj)

  
#
class Type: pass


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
class Value:
  
  def __init__(self, type):
    self.type = _type(type)


#
class Variable(Value):
  
  def __init__(self, type, name):
    super().__init__(type)
    self.name = str(name)
    

#
def out(obj):
  return Callable.Out(obj)


#
def inout(obj):
  return Callable.InOut(obj)


#
class Callable:
  
  def __init__(self, result, parameters, **kws):
    self.result = None if result is None or result == "void" else _type(result)
    self.parameters = {str(n): _parameter(t).resolve(self) for n, t in parameters.items()}
    
  @property
  def result_c(self):
    return "void" if self.result is None else str(self.result)

  @property
  def signature_c(self):
    return "%s(%s)" % (self.result_c, ", ".join(str(t) for t in self.parameters.values()))

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
class Macro(Callable):
  
  def resolve_in(self, type):
    return type.rvalue_type
  
  def resolve_out(self, type):
    return type.lvalue_type
  
  def resolve_inout(self, type):
    return type.rvalue_type
  
  
#
class Functional(Callable):
  
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
  
  def __init__(self, result, name, parameters, **kws):
    super().__init__(result, parameters, **kws)
    self.name = str(name)