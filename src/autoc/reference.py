from itertools import islice
from autoc.memory import Manager
from autoc.composite import Composite
from autoc.core import Indirection, Callable, out, inout


#  
class _Reference(Indirection, Composite):
  
  def __init__(self, type, name=None, *args, **kws):
    super().__init__(type, type.name if name is None else name, *args, **kws)
    
  def __setup__(self):
    super().__setup__()

    self.method(Callable.Parameter(self), "new", {name: type for name, type in islice(self.type.create.parameters.items(), 1, None)})
    self.macro("create", None, {"target": out(self)} | self.new.parameters, lambda target, *args: f"{target} = {self.new(*args)}")

    self.method(Callable.Parameter(self), "share", {"source": inout(self)})
    self.macro_of("copy", lambda target, source: f"{target} = {self.share(source)}")
    
    self.method(None, "free", {"target": inout(self)})
    self.macro_of("destroy", lambda target: self.free(target))
    
    # Delete self attributes which arent handled by the class to force proxying
    del self.equal
    del self.compare
    del self.hash
    
  def __getattr__(self, name):
    return getattr(self.type, name)
  
  @property
  def rvalue_type(self):
    return self

  @property
  def lvalue_type(self):
    return self


#
class Raw(_Reference):
  
  def __init__(self, *args, memory=Manager(), **kws):
    super().__init__(*args, **kws)
    self.memory = memory
    
  def __setup__(self):
    super().__setup__()
    
    with self.new as f:
      # TODO extra parameters
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        {result} = {self.memory.allocate(self.type)}; assert({result});
        {self.type.create(result, *f.arguments)};
        return {result};
      """
      
    with self.share as f:
      f.inline_code = f"""
        assert(source);
        return {f.source};
      """
      
    with self.free as f:
      f.code = f"""
        assert({f.target});
        {self.type.destroy(f.target) if self.type.destructible else str()};
        {self.memory.free(f.target)};
      """
      