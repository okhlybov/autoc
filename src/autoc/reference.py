import autoc.std as std
from itertools import islice
from autoc.memory import Manager
from autoc.core import Composite, _StructRenderer, Indirection, Callable, out


#  
class _Reference(Indirection, Composite):
  
  def __init__(self, type, *args, name=None, **kws):
    super().__init__(type, type.name if name is None else name, *args, **kws)
    
  def __setup__(self):
    super().__setup__()

    self.method(Callable.Parameter(self), "new", {name: type for name, type in islice(self.type.create.parameters.items(), 1, None)})
    self.macro("create", None, {"target": out(self)} | self.new.parameters, lambda target, *args: f"{target} = {self.new(*args)}")

    self.method(self, "share", {"source": self})
    self.macro_from("copy", lambda target, source: f"{target} = ({self}){self.share(source)}")
    
    self.method(None, "free", {"target": self})
    self.macro_from("destroy", lambda target: self.free(target))
    
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
    self.dependencies.update((self.memory, std.assert_h))
    
  def __setup__(self):
    super().__setup__()
    
    with self.new as f:
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
        {self.memory.free(f"({self._layout}*){f.target}")};
      """


#
class Arc(_StructRenderer, _Reference):
  
  def __init__(self, *args, memory=Manager(), **kws):
    super().__init__(*args, **kws)
    self.memory = memory
    self.dependencies.update((self.memory, std.assert_h))
    self._layout = self._decorate_component("layout")
    
  def __setup__(self):
    super().__setup__()
    
    with self.new as f:
      value = self.type.variable("storage->value")
      f.inline_code = f"""
        {self._layout}* storage;
        storage = {self.memory.allocate(f"sizeof({self._layout})", cast=self._layout)}; assert(storage);
        {self.type.create(value, *f.arguments)};
        storage->count = 1;
        return ({f.result})storage;
      """
      
    with self.share as f:
      f.inline_code = f"""
        assert(source);
        ++(({self._layout}*){f.source})->count;
        return {f.source};
      """
      
    with self.free as f:
      f.code = f"""
        assert({f.target});
        if(--(({self._layout}*){f.target})->count == 0) {{
          {self.type.destroy(f.target) if self.type.destructible else str()};
          {self.memory.free(f"({self._layout}*){f.target}")};
        }}
      """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    stream.append("/** @internal */\n")
    stream.append(f"""typedef struct {{
      {self.type} value;
      unsigned count;
    }} {self._layout};
    """)      