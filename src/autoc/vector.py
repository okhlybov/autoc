import autoc.core
from autoc.core import out
import autoc.composite
import autoc.std as std
import autoc.memory


#
class Vector(autoc.composite.Composite, autoc.core._Disabled):

  def __init__(self, name, element, memory=autoc.memory.Manager(), *args, **kws):
    super().__init__(name, *args, **kws)
    self.element = autoc.core._type(element)
    self.memory = memory
    self.dependencies.update([std.assert_h, self.element, self.memory])

  def __setup__(self):
    super().__setup__()
    
    #
    self.create.code = """
      assert(target);
      target->elements = NULL;
      target->size = 0;
    """
    
    # TODO make use of zero initializable feature of primitives
    self.method(None, ("create", "size"), {"target": out(self), "size": std.size_t}, code=f"""
      assert(target);
      if(size > 0) {{
        size_t i;
        target->elements = {self.memory.allocate(self.element, "size")}; assert(target->elements);
        for(i = 0; i < size; ++i) {self.element.create(f"target->elements[i]")};
      }} else target->elements = NULL;
      target->size = size;
    """)

    if self.element.destructible:
      self.destroy.code = f"""
        size_t i;
        assert(target);
        if(target->size > 0) {{
          for(i = 0; i < target->size; ++i) {self.element.destroy("target->elements[i]")};
          {self.memory.free("target->elements")};
        }}
      """
    else:
      self.destroy.code = f"""
        assert(target);
        if(target->size > 0) {self.memory.free("target->elements")};
      """
    
  def _render_struct(self, stream):
    if self.public:
      stream.append("/** @public */\n")
    if self.private:
      stream.append("/** @private */\n")
    stream.append(f"""typedef struct {{
      {autoc.core.Pointer(self.element)} elements; /**< @private */
      {std.size_t} size; /**< @private */
    }} {self.name};
    """)

  def render_interface(self, stream):
    super().render_interface(stream)
    if not self.internal:
      self._render_struct(stream)

  def render_forward_declarations(self, stream):
    super().render_forward_declarations(stream)
    if self.internal:
      self._render_struct(stream)
      
  @property
  def constructible(self): return True
  
  @property
  def destructible(self): return True