import autoc.memory
import autoc.composite
import autoc.std as std
from autoc.core import out, Pointer

#
class Vector(autoc.composite.Collection):

  def __setup__(self):
    super().__setup__()
    
    source_i = self.element.variable("source->elements[index]")
    target_i = self.element.variable("target->elements[index]")
    left_i = self.element.variable("left->elements[index]")
    right_i = self.element.variable("right->elements[index]")
    result = self.element.variable("result")

    self.method(std.size_t, "size", {"target": self}, linkage="INLINE", code=f"""
      assert(target);
      return target->size;
    """)
    
    self.allocate = self.method(None, "allocate", {"target": out(self), "capacity": std.size_t}, visibility="PRIVATE", code=f"""
      assert(target);
      if(capacity > 0) {{
        target->elements = {self.memory.allocate(self.element, "capacity")}; assert(target->elements);
      }} else target->elements = NULL;
      target->size = capacity;
    """)
    
    # TODO make use of zero initializable feature of primitives
    create_size = self.method(None, ("create", "size"), {"target": out(self), "size": std.size_t})
    create_size.code=f"""
      assert(target);
      if(size > 0) {{
        size_t index;
        {self.allocate(*create_size.arguments)};
        for(index = 0; index < size; ++index) {self.element.create(target_i)};
      }} else {{
        target->elements = NULL;
        target->size = 0;
      }}
    """
    self.method(self.element, "get", {"target": self, "index": std.size_t}, linkage="INLINE", code=f"""
      {result.definition};
      assert(target);
      assert(index < target->size);
      {self.element.copy(result, target_i)};
      return result;
    """)
    
    destroy_i = self.element.destroy(target_i) if self.element.destructible else str()
    
    set = self.method(None, "set", {"target": out(self), "index": std.size_t, "element": self.element}, linkage="INLINE")
    set.code=f"""
      assert(target);
      {destroy_i};
      {self.element.copy(target_i, set.arguments[2])};
    """

    self.create.linkage = "INLINE"    
    self.create.code = """
      assert(target);
      target->elements = NULL;
      target->size = 0;
    """
    
    if self.element.destructible:
      self.destroy.code = f"""
        size_t index;
        assert(target);
        if(target->size > 0) {{
          for(index = 0; index < target->size; ++index) {self.element.destroy(target_i)};
          {self.memory.free("target->elements")};
        }}
      """
    else:
      self.destroy.code = f"""
        assert(target);
        if(target->size > 0) {self.memory.free("target->elements")};
      """

    if self.comparable:
      self.equal.code = f"""
        assert(left);
        assert(right);
        if(left->size == right->size) {{
          size_t index;
          for(index = 0; index < left->size; ++index) {{
            if(!{self.element.equal(left_i, right_i)}) return 0;
          }}
          return 1;
        }} else return 0;
      """
    
    if self.hashable:
      state = self.hasher.state_t.variable("state")
      self.hash.code = f"""
        size_t index, result;
        {state.definition};
        assert(target);
        {self.hasher.create("state")};
        for(index = 0; index < target->size; ++index) {self.hasher.update(state, self.element.hash(target_i))};
        result = {self.hasher.hash(state)};
        {self.hasher.destroy(state)};
        return result;
      """

    if self.copyable:
      self.copy.code = f"""
        size_t index;
        assert(target);
        assert(source);
        {self.allocate("target", "source->size")};
        for(index = 0; index < target->size; ++index) {self.element.copy(target_i, source_i)};
      """

  def _render_struct(self, stream):
    if self.public:
      stream.append("/** @public */\n")
    if self.private:
      stream.append("/** @private */\n")
    stream.append(f"""typedef struct {{
      {Pointer(self.element)} elements; /**< @private */
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
  
  @property
  def comparable(self):
    return self.element.comparable
  
  @property
  def hashable(self):
    return self.element.hashable
  
  @property
  def copyable(self):
    return self.element.copyable
  
  @property
  def orderable(self):
    return False