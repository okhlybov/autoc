import autoc.memory
import autoc.std as std
from autoc.core import inout, Pointer
from autoc.composite import Composite, _StructRenderer
from functools import cached_property


#
class Reference(Composite, Pointer):
  
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

  def __getattr__(self, name):
    return getattr(self.base, name)
  
  def _proxy(self, identifier, proxy):
    params = proxy.parameters.copy(); del params["target"]
    m = self.method(self, identifier, params)
    m.__proxy__ = proxy
    return m

  def proxy_new(self, identifier, proxy):
    with self._proxy(identifier, proxy) as f:
      result = self.variable("result")
      f.inline = f"""
        {result.definition};
        result = {self.memory.allocate(self.base)}; assert(result);
        {f.__proxy__(result, *f.arguments)};
        return {result};
      """

  def __setup__(self):
    super().__setup__()

    with self.method(self, "new", {}) as f:
      result = self.variable("result")
      create = self.base.create(result) if self.base.constructible else str()
      f.inline = f"""
        {result.definition};
        result = {self.memory.allocate(self.base)}; assert(result);
        {create};
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

    with self.as_method("create", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(target);
        *target = {self.new()};
      """

    with self.as_method("destroy", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(target);
        {self.free(f.target)};
      """

    with self.as_method("copy", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(target);
        assert(source);
        *target = {f.source};
      """

    with self.as_method("equal", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(left);
        assert(right);
        return {self.base.equal(f.left, f.right)};
      """

    with self.as_method("hash", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(target);
        return {self.base.hash(f.target)};
      """

    with self.as_method("compare", visibility="PRIVATE", hidden=True) as f:
      f.inline = f"""
        assert(left);
        assert(right);
        return {self.base.compare(f.left, f.right)};
      """

  @property
  def constructible(self):
    return self.base.constructible

  @property
  def comparable(self):
    return self.base.comparable
  
  @property
  def hashable(self):
    return self.base.hashable

  @property
  def orderable(self):
    return self.base.orderable


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

  def proxy_new(self, identifier, proxy):
    with self._proxy(identifier, proxy) as f:
      result = self.variable("result")
      f.inline = f"""
        {result.definition};
        result = {self.memory.allocate(f"sizeof({self._storage})", cast=self.base)}; assert(result);
        {f.__proxy__(result, *f.arguments)};
        (({self._storage}*)result)->count = 1;
        return {result};
      """

  def __setup__(self):
    super().__setup__()
    
    with self.new as f:
      result = self.variable("result")
      create = self.base.create(result) if self.base.constructible else str()
      f.inline = f"""
        {result.definition};
        result = {self.memory.allocate(f"sizeof({self._storage})", cast=self.base)}; assert(result);
        {create};
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