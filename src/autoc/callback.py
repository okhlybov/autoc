import autoc.std as std
from autoc.core import Primitive, Variable, Statement, Expression
from autoc.core import _type, _value, _parameter
from autoc.module import Code


#
# Primitive type representing a C function pointer suitable for element type of containers.
#
# The type is rendered as a typedef emitted into the interface header:
#   typedef R (*name)(T1, T2);
# so that the typedef name behaves exactly like any other primitive value type:
# create (null constant), copy/move (assignment), equal (address comparison), hash (cast to size_t).
#
# Calling through a value of this type is supported from the Python layer either via
# the type-level call(target, *arguments) or by calling a variable of this type directly:
#   v = unary.variable("v")
#   ... f"{v(x)}" renders as (v)(x)
#
# FIXME more to core, rename to Functional? Make use of existing Callable infrastructure
class Callback(Primitive):

  def __init__(self, name, signature=None, *args, result=None, parameters=None, **kws):
    # The signature may either be supplied as a Callable instance (its result and parameters are borrowed)
    # or by the explicit result/parameters keyword arguments
    if signature is not None:
      if result is None: result = signature._result
      if parameters is None: parameters = signature._parameters
    super().__init__(name, *args, **kws)
    self.result = None if result is None or result == "void" else _type(result)
    self.parameters = {str(n): _parameter(t).resolve(self) for n, t in dict(parameters or {}).items()}
    # Parameter conventions of function pointers match those of functions - values are passed
    # exactly as the corresponding function would receive them
    arguments_c = ", ".join(str(t) for t in self.parameters.values()) or "void"
    result_c = "void" if self.result is None else str(self.result)
    # The typedef must be visible wherever the element type is used - emit it as the interface code
    self._typedef = Code(
      interface=f"typedef {result_c} (*{self.name})({arguments_c});",
      dependencies=[t for t in (*self.parameters.values(), self.result) if t is not None],
    )
    self.dependencies.update((self._typedef, *self.parameters.values(), *([self.result] if self.result else [])))

  def __setup__(self):
    super().__setup__()
    # Relational comparison of function pointers is undefined in C - only the equality is well-defined
    # so disable the ordering support inherited from the primitive type
    self.compare = None

  @property
  def orderable(self):
    return False

  # Resolution shims used when the parameter specifications are resolved against this type
  def resolve_in(self, type):
    return type.in_type

  def resolve_out(self, type):
    return type.out_type

  def resolve_inout(self, type):
    return type.inout_type

  #
  def call(self, target, *arguments):
    # Renders the call of the function pointed to by the target expression
    if (na := len(arguments)) != (np := len(self.parameters)):
      raise TypeError(f"{self} takes {np} parameter(s) but {na} given")
    bound = [_value(a).bind(t) for a, t in zip(arguments, self.parameters.values())]
    contents = f"({_value(target).bind(self)})({', '.join(bound)})"
    return Statement(contents) if self.result is None else Expression(self.result, contents)

  def variable(self, name):
    return Callback.Variable(self, name)

  class Variable(Variable):

    # Variables of the callback type are callable through the Python layer
    def __call__(self, *arguments):
      return self.type.call(str(self), *arguments)
