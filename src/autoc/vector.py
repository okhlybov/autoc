import autoc.hash
import autoc.std as std
from autoc.core import out, inout, Pointer
from autoc.range import DirectAccess
from autoc.composite import _StructRenderer
from autoc.collection import _Range, Collection


#
class Vector(_StructRenderer, Collection):

  def __init__(self, *args, hasher=autoc.hash.XorShift(), **kws):
    super().__init__(*args, hasher=hasher, **kws)
    self.range = Range(self)


  def __setup__(self):
    super().__setup__()
    
    source_i = self.element.variable("source->elements[index]")
    target_i = self.element.variable("target->elements[index]")
    left_i = self.element.variable("left->elements[index]")
    right_i = self.element.variable("right->elements[index]")
    result = self.element.variable("result")

    self.empty.linkage = "INLINE"
    self.empty.code = f"""
      assert(target);
      return target->size == 0;
    """
    self._inline_policy(self.empty)
    
    self.index = self.method("int", "index", {"target": self, "index": std.size_t}, linkage="INLINE", code=f"""
      assert(target);
      return index < target->size;
    """)
    self._inline_policy(self.index)
    
    self.size = self.method(std.size_t, "size", {"target": self}, linkage="INLINE", code=f"""
      assert(target);
      return target->size;
    """)
    self._inline_policy(self.size)
    
    self.allocate = self.method(None, "allocate", {"target": out(self), "capacity": std.size_t}, visibility="PRIVATE", code=f"""
      assert(target);
      if(capacity > 0) {{
        target->elements = {self.memory.allocate(self.element, "capacity")}; assert(target->elements);
      }} else target->elements = NULL;
      target->size = capacity;
    """)
    self._inline_policy(self.allocate)
    
    # TODO make use of zero initializable feature of primitives
    self.create_size = self.method(None, ("create", "size"), {"target": out(self), "size": std.size_t})
    self.create_size.code = f"""
      assert(target);
      if(size > 0) {{
        size_t index;
        {self.allocate(*self.create_size.arguments)};
        for(index = 0; index < size; ++index) {self.element.create(target_i)};
      }} else {{
        target->elements = NULL;
        target->size = 0;
      }}
    """
    self._inline_policy(self.create_size)

    self.get = self.method(self.element, "get", {"target": self, "index": std.size_t}, linkage="INLINE", code=f"""
      {result.definition};
      assert(target);
      assert({self.index("target", "index")});
      {self.element.copy(result, target_i)};
      return result;
    """)
    self._inline_policy(self.get)
    
    # FIXME explicit casting here and ithere in the respective Range type is a kind of hack to deal with double pointer types
    # Normally Pointer type should be responsible for handling the per-indirection constness flags
    
    self.view = self.method(self.element_view, "view", {"target": self, "index": std.size_t}, linkage="INLINE")
    self.view.code = f"""
      assert(target);
      assert({self.index("target", "index")});
      return ({self.view.result})&{target_i};
    """
    self._inline_policy(self.view)

    destroy_i = self.element.destroy(target_i) if self.element.destructible else str()
    
    self.set = self.method(None, "set", {"target": out(self), "index": std.size_t, "element": self.element}, linkage="INLINE")
    self.set.code = f"""
      assert(target);
      assert({self.index("target", "index")});
      {destroy_i};
      {self.element.copy(target_i, self.set.arguments[2])};
    """
    self._inline_policy(self.set)

    self.create.linkage = "INLINE"    
    self.create.code = """
      assert(target);
      target->elements = NULL;
      target->size = 0;
    """
    self._inline_policy(self.create)
    
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
    self._inline_policy(self.destroy)
    
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
    self._inline_policy(self.equal)
    
    self.copy.code = f"""
      size_t index;
      assert(target);
      assert(source);
      {self.allocate("target", "source->size")};
      for(index = 0; index < target->size; ++index) {self.element.copy(target_i, source_i)};
    """
    self._inline_policy(self.copy)

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


#
class Range(_Range, DirectAccess):
  
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Pointer(self.iterable)} iterable; /**< @private */
          {std.size_t} front, back; /**< @private */
        }} {self.name};
      """)

  def _copy(self, result, parameters, **kws):
    return autoc.core.Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  def __setup__(self):
    super().__setup__()

    self.new = self.method(self, "new", {"iterable" : inout(self.iterable)})

    self.new.linkage = "INLINE"
    self.new.code = f"""
      assert(iterable);
      return ({self}){{ iterable, 0, {self.iterable.size(self.new.iterable)} }};
    """

    self.empty.linkage = "INLINE"
    self.empty.code = f"""
      assert(target);
      return target->front >= target->back;
    """

    target = self.empty.target

    self.front.linkage = "INLINE"
    self.front.code = f"""
      assert(target);
      assert(!{self.empty(target)});
      return {self.iterable.get("target->iterable", "target->front")};
    """

    self.front_view.linkage = "INLINE"
    self.front_view.code = f"""
      assert(target);
      assert(!{self.empty(target)});
      return ({self.front_view.result}){self.iterable.view("target->iterable", "target->front")};
    """

    self.move_front.linkage = "INLINE"
    self.move_front.code = f"""
      assert(target);
      assert(!{self.empty(target)});
      ++target->front;
    """

    self.back.linkage = "INLINE"
    self.back.code = f"""
      assert(target);
      assert(!{self.empty(target)});
      return {self.iterable.get("target->iterable", "target->back-1")};
    """

    self.back_view.linkage = "INLINE"
    self.back_view.code = f"""
      assert(target);
      assert(!{self.empty(target)});
      return ({self.back_view.result}){self.iterable.view("target->iterable", "target->back-1")};
    """

    self.move_back.linkage = "INLINE"
    self.move_back.code = f"""
      assert(target);
      assert(!{self.empty(self.move_back.target)});
      --target->back;
    """

    self.get.linkage = "INLINE"
    self.get.code = f"""
      assert(target);
      return {self.iterable.get("target->iterable", "target->front + index")};
    """

    self.view.linkage = "INLINE"
    self.view.code = f"""
      assert(target);
      return {self.iterable.view("target->iterable", "target->front + index")};
    """

    self.size.linkage = "INLINE"
    self.size.code = f"""
      assert(target);
      assert(target->back >= target->front);
      return target->back - target->front;
    """