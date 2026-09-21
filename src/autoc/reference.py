import autoc.std as std
from itertools import islice
from autoc.memory import Manager
from autoc.core import Composite, _StructRenderer, _AliasRenderer, Indirection, Callable, out, inout


#  
class _Reference(Indirection, Composite):
  
  def __init__(self, type, *args, name=None, **kws):
    super().__init__(type, type.name if name is None else name, *args, **kws)
    
  def __setup__(self):
    super().__setup__()

    self.method(Callable.Parameter(self), "new", {name: type for name, type in islice(self.type.create.parameters.items(), 1, None)}, brief="Create the reference owning a new instance of the type",
      description="""
        Allocates a new instance of the referenced type, constructs it with the given
        parameters and returns the reference owning it. The instance lives until every
        reference to it is released.

        @return the reference to the newly allocated instance - releasing this reference frees the instance
      """)
    self.macro("create", None, {"target": out(self)} | self.new.parameters, lambda target, *args: f"{target} = {self.new(*args)}")

    self.method(self, "share", {"source": self}, brief="Share the instance by increasing its reference count",
      description="""
        Returns another reference to the instance the source references without duplicating
        it - the referenced instance stays alive as long as at least one reference to it exists.

        @param[in] source the reference to share - must reference a valid instance
        @return another reference to the same instance - the shared instance stays owned by the caller as well
      """)
    self.macro_from("copy", lambda target, source: f"{target} = {self.share(source)}")
    
    self.method(None, "free", {"target": self}, brief="Decrement reference count",
      description="""
        Releases one ownership of the referenced instance - the instance is destroyed and
        its memory freed only when the last reference to it is released, making this safe
        to pair with the sharing.

        @param[in] target the reference to release - the instance is destroyed when its last reference is released, a null reference is ignored
      """)
    self.macro_from("destroy", lambda target: self.free(target))
    
    # A moved-from reference is nulled so that destroying it afterwards is a safe no-op
    # The underlying free guards on the pointer being NULL
    self.macro_from("move", lambda target, source: f"{target} = {source}, {source} = NULL")
    # Swapping exchanges the handles without touching the reference counts on either side
    self.swap = self.method(None, "swap", {"left": inout(Indirection(self)), "right": inout(Indirection(self))}, brief="Swap two references",
      description="""
        Exchanges the two reference handles in constant time without touching the reference
        counts - the instances referenced stay exactly as owned as they were.

        @param[in,out] left the first reference
        @param[in,out] right the second reference
      """)
    with self.swap as f:
      f.inline_code = f"""
        {self} temp;
        temp = *left;
        *left = *right;
        *right = temp;
      """

    
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
  
  @property
  def view_type(self):
    return self.constness(True)


#
class Raw(_AliasRenderer, _Reference):

  brief = "Non-owning reference to a manually managed instance"
  
  def __init__(self, *args, memory=Manager(), **kws):
    super().__init__(*args, **kws)
    self.memory = memory
    self.dependencies.update((self.memory, std.assert_h))
    
  def __setup__(self):
    super().__setup__()

    self.new.brief = "Create the reference owning a new instance of the type"
    self.new.description = """
      Allocates a new instance of the referenced type, constructs it with the given
      parameters and returns the unmanaged reference owning it. The caller is responsible
      for releasing the instance with free.

      @return the reference to the newly allocated instance - releasing this reference frees the instance
    """

    self.share.brief = "Duplicate reference handle"
    self.share.description = """
      Returns another unmanaged reference to the same instance without duplicating it
      or modifying ownership.

      @param[in] source the reference to share - must reference a valid instance
      @return another reference to the same instance
    """

    self.free.brief = "Free referenced instance"
    self.free.description = """
      Destroys and releases the referenced instance immediately. Any other handles
      referencing this instance become invalid. A null reference is ignored.

      @param[in] target the reference to release - the instance is destroyed and its memory freed, a null reference is ignored
    """

    self.swap.brief = "Swap two references"
    self.swap.description = """
      Exchanges the two reference handles in constant time without copying or destroying
      the referenced instances.

      @param[in,out] left the first reference
      @param[in,out] right the second reference
    """
    
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
        return ({self}){f.source};
      """
      
    with self.free as f:
      # Raw bears no layout of its own: new() allocates the referenced type
      # directly, so free() releases exactly that allocation
      f.code = f"""
        if({f.target}) {{
          {self.type.destroy(f.target) if self.type.destructible else str()};
          {self.memory.free(f.target)};
        }}
      """


#
class Arc(_StructRenderer, _Reference):
  
  brief = "Reference counted shared instance proxy type"
  
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
        return ({self}){f.source};
      """
      
    with self.free as f:
      f.inline_code = f"""
        if({f.target}) {{
          if(--(({self._layout}*){f.target})->count == 0) {{
            {self.type.destroy(f.target) if self.type.destructible else str()};
            {self.memory.free(f"({self._layout}*){f.target}")};
          }}
        }}
      """

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append("/** @private */\n")
    stream.append(f"""
      typedef struct {{
        {self.type} value;
        unsigned count;
      }} {self._layout};
    """)      