import autoc.memory
import autoc.std as std
from autoc.core import out, inout, Pointer, Macro, _type
from autoc.composite import Composite, _StructRenderer
from functools import cached_property
from itertools import islice


#
class _Reference(Pointer, Composite):
  
  def __init__(self, type, *args, memory=autoc.memory.Manager(), dependencies=[], prefix=None, **kws):
    super().__init__(type, *args, dependencies=[*dependencies, std.assert_h, memory], prefix=prefix if prefix else str(type), **kws)
    self.memory = memory
    self.depends(self.base)
  
  @property
  def destructible(self):
    return super(Composite, self).destructible # Circumvent Pointer's primitive definition

  @property
  def lvalue_type(self):
    return self

  @property
  def rvalue_type(self):
    return self.base
  
  @cached_property
  def in_type(self):
    return _type(self.as_const())
  
  @cached_property
  def out_type(self):
    return _type(Pointer(self))

  @property
  def inout_type(self):
    return self

  def __setup__(self):
    super().__setup__()

    self.method(self, "new", dict(islice(self.base.create.parameters.items(), 1, None)))

    self.method(None, "free", {"target": inout(self)})

    self.method(self, "share", {"target": inout(self)})

    with self.method(None, "foo", {"target": self}) as f:
      f.code = ""
    
    self.create = Macro(None, {"target": out(self)} | self.new.parameters, lambda target, *arguments: f"{target} = {self.new(*arguments)}")
    
    self.as_macro("destroy", lambda target: str(self.free(target)))
    
    self.as_macro("copy", lambda target, source: f"{target} = {self.share(source)}")
    
    self.as_macro("equal", lambda left, right: str(self.base.equal(left, right)))
    
    self.as_macro("compare", lambda left, right: str(self.base.compare(left, right)))
    
    self.as_macro("hash", lambda target: str(self.base.hash(target)))


# Plain unmanaged reference
class Raw(_Reference):
  
  def __setup__(self):
    super().__setup__()
    
    with self.new as f:
      result = self.variable("result")
      f.inline = f"""
        {result.definition} = {self.memory.allocate(self.base)}; assert({result});
        {self.base.create(result, *f.arguments)};
        return {result};
      """

    with self.free as f:      
      f.inline = f"""
        assert(target);
        {self.base.destroy(f.target) if self.base.destructible else str()};
        {self.memory.free(f.target)};
      """

    with self.share as f:
      f.inline = f"""
        assert(target);
        return target;
      """


#
class Shared(_StructRenderer, _Reference):
  
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
        {result.definition} = {self.memory.allocate(f"sizeof({self._storage})", cast=self.base)}; assert(result);
        (({self._storage}*)result)->count = 1;
        {self.base.create(result, *f.arguments)};
        return {result};
      """

    with self.free as f:      
      f.inline = f"""
        assert(target);
        if(--((({self._storage}*)target)->count) == 0) {{
          {self.base.destroy(f.target) if self.base.destructible else str()};
          {self.memory.free(f.target)};
        }}
      """

    with self.share as f:
      f.inline = f"""
        assert(target);
        ++((({self._storage}*)target)->count);
        return target;
      """