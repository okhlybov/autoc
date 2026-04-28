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

    super().__setup__()

  @property
  def constructible(self):
    return self.base.constructible

  def _create(self, result, parameters, **kws):
    with self.method(result, "create_", parameters, visibility="PRIVATE", hidden=True, **kws) as f:
      f.inline = f"""
        *target = NULL;
      """
    return f

  @property
  def destructible(self):
    return True
  
  def _destroy(self, result, parameters, **kws):
    with self.method(result, "destroy_", parameters, visibility="PRIVATE", hidden=True, **kws) as f:
      f.inline = f"""
        assert(target);
        {self.free(f.target)};
      """
    return f

  @property
  def copyable(self):
    return True
  
  def _copy(self, result, parameters, **kws):
    with self.method(result, "copy_", parameters, visibility="PRIVATE", hidden=True, **kws) as f:
      f.inline = f"""
        assert(target);
        assert(source);
        *target = {f.source};
      """
    return f

  @property
  def comparable(self):
    return self.base.comparable
  
  def _equal(self, result, parameters, **kws):
    with self.method(result, "equal_", parameters, visibility="PRIVATE", hidden=True, **kws) as f:
      f.inline = f"""
        assert(left);
        assert(right);
        return left == right;
      """
    return f
  
  @property
  def hashable(self):
    return self.base.hashable
  
  def _hash(self, result, parameters, **kws):
    with self.method(result, "hash_", parameters, visibility="PRIVATE", hidden=True, **kws) as f:
      f.inline = f"""
        assert(target);
        return (size_t){f.target};
      """
    return f

  @property
  def orderable(self):
    return False