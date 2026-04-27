import autoc.memory
import autoc.std as std
from autoc.core import *
from autoc.composite import Composite, _StructRenderer
from functools import cached_property


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
  
  def in_type(self):
    return self
  
  @cached_property
  def out_type(self):
    return Pointer(self)

  @property
  def inout_type(self):
    return self

  def __setup__(self):

    with self.method(self, "new", {}) as f:
      result = self.variable("result")
      f.inline = f"""
        {result.definition};
        result = {self.memory.allocate(self.base)}; assert(result);
        {self.base.create(result)};
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
        *target = {self.new()};
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
        return {self.base.equal(f.left, f.right)};
      """
    return f
  
  @property
  def hashable(self):
    return self.base.hashable
  
  def _hash(self, result, parameters, **kws):
    with self.method(result, "hash_", parameters, visibility="PRIVATE", hidden=True, **kws) as f:
      f.inline = f"""
        return {self.base.hash(f.target)};
      """
    return f

  @property
  def orderable(self):
    return self.base.orderable
  
  def _compare(self, result, parameters, **kws):
    with self.method(result, "compare_", parameters, visibility="PRIVATE", hidden=True, **kws) as f:
      f.inline = f"""
        assert(left);
        assert(right);
        return {self.base.compare(f.left, f.right)};
      """
    return f


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
    
    with self.new as f:
      result = self.variable("result")
      f.inline = f"""
        {result.definition};
        result = {self.memory.allocate(f"sizeof({self._storage})", cast=self.base)}; assert(result);
        {self.base.create(result)};
        (({self._storage}*)result)->count = 1;
        return result;
      """
    
    with self.share as f:
      f.inline = f"""
        assert(target);
        ++(({self._storage}*)target)->count;
        return target;
      """

    with self.free as f:
      destroy = self.base.destroy(f.target) if self.base.destructible else str()
      f.inline = f"""
      assert(target);
      if(--(({self._storage}*)target)->count == 0) {{
        {destroy};
        {self.memory.free(f.target)};
      }}
    """

    with self.copy as f:
      f.inline = f"""
        assert(target);
        assert(source);
        *target = {self.share(f.source)};
      """