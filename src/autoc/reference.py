import autoc.memory
import autoc.std as std
from autoc.core import *
from autoc.composite import Composite, _StructRenderer
from functools import cached_property


# FIXME use with:

#
class Reference(Composite, Pointer):
  
  def __init__(self, type, memory=autoc.memory.Manager(), dependencies=[], *args, **kws):
    super().__init__(type, *args, dependencies=[*dependencies, std.assert_h, memory], **kws)
    self.memory = memory
    self.depends(self.base)
    
  @property
  def lvalue_type(self):
    return self
  
  @property
  def rvalue_type(self):
    return self.base
  
  @cached_property
  def in_type(self):
    return self
  
  @cached_property
  def out_type(self):
    return Pointer(self)

  @property
  def inout_type(self):
    return self

  def __setup__(self):

    self.new = self.method(self, "new", {}, linkage="INLINE")
    result = Variable(self, "result")
    self.new.code = f"""
      {result.definition};
      result = {self.memory.allocate(self.base)}; assert(result);
      {self.base.create(result)};
      return result;
    """
    
    self.share = self.method(self, "share", {"target": inout(self)}, linkage="INLINE")
    self.share.code = f"""
      assert(target);
      return target;
    """

    self.free = self.method(None, "free", {"target": inout(self)}, linkage="INLINE")
    destroy = self.base.destroy(*self.free.arguments) if self.base.destructible else str()
    self.free.code = f"""
      assert(target);
      {destroy};
      {self.memory.free(*self.free.arguments)};
    """

    super().__setup__()

  @property
  def constructible(self):
    return self.base.constructible

  def _create(self, result, parameters, **kws):
    method = self.method(result, "create_", parameters, linkage="INLINE", visibility="PRIVATE", hidden=True, dependencies=[self.new], **kws)
    method.code = f"*target = {self.new()};"
    return method
  
  @property
  def destructible(self):
    return True
  
  def _destroy(self, result, parameters, **kws):
    method = self.method(result, "destroy_", parameters, linkage="INLINE", visibility="PRIVATE", hidden=True, dependencies=[self.free], **kws)
    method.code = f"{self.free(method.target)};"
    return method

  @property
  def copyable(self):
    return True
  
  def _copy(self, result, parameters, **kws):
    method = self.method(result, "copy_", parameters, linkage="INLINE", visibility="PRIVATE", hidden=True, **kws)
    method.code = f"""
      assert(target);
      assert(source);
      *target = {method.source};
    """
    return method

  @property
  def comparable(self):
    return self.base.comparable
  
  def _equal(self, result, parameters, **kws):
    method = self.method(result, "equal_", parameters, linkage="INLINE", visibility="PRIVATE", hidden=True, **kws)
    method.code = f"return {self.base.equal(method.left, method.right)};"
    return method
  
  @property
  def hashable(self):
    return self.base.hashable
  
  def _hash(self, result, parameters, **kws):
    method = self.method(result, "hash_", parameters, linkage="INLINE", visibility="PRIVATE", hidden=True, **kws)
    method.code = f"return {self.base.hash(method.target)};"
    return method

  @property
  def orderable(self):
    return self.base.orderable
  
  def _compare(self, result, parameters, **kws):
    method = self.method(result, "compare_", parameters, linkage="INLINE", visibility="PRIVATE", hidden=True, **kws)
    method.code = f"return {self.base.compare(method.left, method.right)};"
    return method


#
class Shared(_StructRenderer, Reference):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self._storage = self.decorate("storage", hidden=True)
    
  def _render_struct(self, stream):
    stream.append("/** @internal */\n")
    stream.append(f"""typedef struct {{
      {self.base} value;
      {std.size_t} count;
    }} {self._storage};
    """)

  def __setup__(self):
    super().__setup__()
    
    self.share.code = f"""
      assert(target);
      ++(({self._storage}*)target)->count;
      return target;
    """

    result = Variable(self, "result")
    self.new.code = f"""
      {result.definition};
      result = {self.memory.allocate(f"sizeof({self._storage})", cast=self.base)}; assert(result);
      {self.base.create(result)};
      (({self._storage}*)result)->count = 1;
      return result;
    """
    
    destroy = self.base.destroy(*self.free.arguments) if self.base.destructible else str()
    self.free.code = f"""
      assert(target);
      if(--(({self._storage}*)target)->count == 0) {{
        {destroy};
        {self.memory.free(*self.free.arguments)};
      }}
    """

    self.copy.dependencies = [self.share]
    self.copy.code = f"""
      assert(target);
      assert(source);
      *target = {self.share(self.copy.source)};
    """