import autoc.module
import autoc.memory
import autoc.std as std
from autoc.core import *
import autoc.composite
from functools import cached_property


#
class Shared(autoc.composite.Composite, Pointer):
  
  def __init__(self, type, memory=autoc.memory.Manager(), dependencies=[], *args, **kws):
    super().__init__(type, *args, dependencies=[*dependencies, std.assert_h, memory], **kws)
    self.memory = memory
    self._depend_on(self.base)
    self._layout = self.decorate("layout", hidden=True)
    
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

  def _render_struct(self, stream):
    if not self.internal:
      stream.append("/** @private */\n")
    stream.append(f"""typedef struct {{
      {self.base} payload;
      {std.size_t} count;
    }} {self._layout};
    """)

  def render_interface(self, stream):
    super().render_interface(stream)
    if not self.internal:
      self._render_struct(stream)

  def render_forward_declarations(self, stream):
    super().render_forward_declarations(stream)
    if self.internal:
      self._render_struct(stream)

  def __setup__(self)  :
    
    self.new = self.method(self, "new", {}, type="INLINE")
    result = Variable(self, "result")
    self.new.code = f"""
      {result.definition};
      result = {self.memory.allocate(f"sizeof({self._layout})", cast=self.base)}; assert(result);
      {self.base.create(result)};
      (({self._layout}*)result)->count = 1;
      return result;
    """
    
    self.free = self.method(None, "free", {"target": inout(self)}, type="INLINE")
    destroy = self.base.destroy(*self.free.arguments) if self.base.destructible else str()
    self.free.code = f"""
      assert(target);
      if(--(({self._layout}*)target)->count == 0) {{
        {destroy};
        {self.memory.free(*self.free.arguments)};
      }}
    """

    self.share = self.method(self, "share", {"target": inout(self)}, type="INLINE")
    self.share.code = f"""
      assert(target);
      ++(({self._layout}*)target)->count;
      return target;
    """

    super().__setup__()

  @property
  def constructible(self):
    return self.base.constructible

  def _create(self, result, parameters, **kws):
    method = self.method(result, ("create", "payload"), parameters, type="INLINE", visibility="PRIVATE", hidden=True, dependencies=[self.new], **kws)
    method.code = f"*target = {self.new()};"
    return method
  
  @property
  def destructible(self):
    return True
  
  def _destroy(self, result, parameters, **kws):
    method = self.method(result, ("destroy", "payload"), parameters, type="INLINE", visibility="PRIVATE", hidden=True, dependencies=[self.free], **kws)
    method.code = f"{self.free("target")};"
    return method

  @property
  def copyable(self):
    return True
  
  def _copy(self, result, parameters, **kws):
    method = self.method(result, ("copy", "payload"), parameters, type="INLINE", visibility="PRIVATE", hidden=True, dependencies=[self.share], **kws)
    method.code = f"*target = {self.share("source")};"
    return method

  @property
  def comparable(self):
    return self.base.comparable
  
  def _equal(self, result, parameters, **kws):
    method = self.method(result, ("equal", "payload"), parameters, type="INLINE", visibility="PRIVATE", hidden=True, **kws)
    method.code = f"return {self.base.equal("left", "right")};"
    return method
  
  @property
  def hashable(self):
    return self.base.hashable
  
  def _hash(self, result, parameters, **kws):
    method = self.method(result, ("hash", "payload"), parameters, type="INLINE", visibility="PRIVATE", hidden=True, **kws)
    method.code = f"return {self.base.hash("target")};"
    return method

  @property
  def orderable(self):
    return self.base.orderable
  
  def _compare(self, result, parameters, **kws):
    method = self.method(result, ("compare", "payload"), parameters, type="INLINE", visibility="PRIVATE", hidden=True, **kws)
    method.code = f"return {self.base.compare("left", "right")};"
    return method
