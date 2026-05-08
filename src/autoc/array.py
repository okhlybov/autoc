import autoc.memory
import autoc.std as std
from autoc.core import inout, Pointer
from autoc.composite import Composite
from functools import cached_property

#
class Array(Composite, Pointer):
  
  def __init__(self, type, *args, memory=autoc.memory.Manager(), dependencies=[], prefix=None, **kws):
    super().__init__(type, *args, dependencies=[*dependencies, std.assert_h, memory], prefix=prefix if prefix else str(type), **kws)
    self.memory = memory
    self.depends(self.base)
    
  @property
  def lvalue_type(self):
    return self
  
  @property
  def rvalue_type(self):
    return self.base
  
  @property
  def in_type(self):
    return self
  
  @cached_property
  def out_type(self):
    return Pointer(self)

  @property
  def inout_type(self):
    return self

  def __setup__(self):
    super().__setup__()

    with self.method(self, "new", {"size": std.size_t}) as f:
      result = self.variable("result")
      f.inline = f"""
        {result.definition};
        result = {self.memory.allocate(self.base, f.size)}; assert(result);
        return {result};
      """
    
    with self.method(self, "share", {"target": inout(self)}) as f:
      f.inline = f"""
        assert(target);
        return target;
      """

    with self.method(None, "free", {"target": inout(self)}) as f:
      destroy = self.base.destroy(f.target) if self.base.destructible else str()
      f.inline = f"""
        assert(target);
        {destroy};
        {self.memory.free(f.target)};
      """

    with self.implement(self.create, "create_", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(target);
        *target = NULL;
      """

    with self.implement(self.destroy, "destroy_", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(target);
        {self.free(f.target)};
      """
      
    with self.implement(self.copy, "copy_", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(target);
        assert(source);
        *target = {f.source};
      """

    with self.implement(self.equal, "equal_", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(left);
        assert(right);
        return left == right;
      """

    with self.implement(self.hash, "hash_", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(target);
        return (size_t){f.target};
      """

  @property
  def orderable(self):
    return False