import autoc.hash
import autoc.std as std
from autoc.range import DirectAccess
from autoc.core import out, inout, Pointer, Macro
from autoc.composite import _StructRenderer
from autoc.collection import _Range as _CollectionRange
from autoc.sequence import Sequence
from autoc.map import Map


#
class Vector(_StructRenderer, Map, Sequence):

  def __init__(self, name, element, hasher=autoc.hash.XorShift(), **kws):
    super().__init__(name, element, std.size_t, hasher=hasher, **kws)
    self.range = Range(self)

  def __setup__(self):
    super().__setup__()
    
    source_i = self.element.variable("source->elements[index]")
    target_i = self.element.variable("target->elements[index]")
    left_i = self.element.variable("left->elements[index]")
    right_i = self.element.variable("right->elements[index]")
    result = self.element.variable("result")

    with self.empty as f:
      f.inline = f"""
        assert(target);
        return target->size == 0;
      """
    
    with self.indexed as f:
      f.inline = f"""
        assert(target);
        return index < target->size;
      """
    
    with self.size as f:
      f.inline = f"""
        assert(target);
        return target->size;
      """
    
    with self.method(None, "allocate", {"target": out(self), "capacity": self.index}, visibility="PRIVATE") as f:
      f.external = f"""
        assert(target);
        if(capacity > 0) {{
          target->elements = {self.memory.allocate(self.element, f.capacity)}; assert(target->elements);
        }} else target->elements = NULL;
        target->size = capacity;
      """
    
    # TODO make use of zero initializable feature of primitives
    with self.method(None, ("create", "size"), {"target": out(self), "size": self.index}) as f:
      f.external = f"""
        assert(target);
        if(size > 0) {{
          {self.index} index;
          {self.allocate(*f.arguments)};
          for(index = 0; index < size; ++index) {self.element.create(target_i)};
        }} else {{
          target->elements = NULL;
          target->size = 0;
        }}
      """

    with self.get as f:
      f.inline = f"""
        {result.definition};
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {self.element.copy(result, target_i)};
        return result;
      """
    
    # FIXME explicit casting here and ithere in the respective Range type is a kind of hack to deal with double pointer types
    # Normally Pointer type should be responsible for handling the per-indirection constness flags
    
    with self.view as f:
      f.inline = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        return ({f.result})&{target_i};
      """

    destroy_i = self.element.destroy(target_i) if self.element.destructible else str()
    
    with self.set as f:
      f.inline = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {destroy_i};
        {self.element.copy(target_i, f.element)};
      """

    with self.create as f:
      f.inline = """
        assert(target);
        target->elements = NULL;
        target->size = 0;
      """
    
    with self.destroy as f:
      if self.element.destructible:
        f.external = f"""
          {self.index} index;
          assert(target);
          if(target->size > 0) {{
            for(index = 0; index < target->size; ++index) {self.element.destroy(target_i)};
            {self.memory.free("target->elements")};
          }}
        """
      else:
        f.external = f"""
          assert(target);
          if(target->size > 0) {self.memory.free("target->elements")};
        """

    # FIXME should come from sequence    
    with self.equal as f:
      f.external = f"""
        assert(left);
        assert(right);
        if(left->size == right->size) {{
          {self.index} index;
          for(index = 0; index < left->size; ++index) {{
            if(!{self.element.equal(left_i, right_i)}) return 0;
          }}
          return 1;
        }} else return 0;
      """

    with self.copy as f:
      f.external = f"""
        {self.index} index;
        assert(target);
        assert(source);
        {self.allocate(f.target, "source->size")};
        for(index = 0; index < target->size; ++index) {self.element.copy(target_i, source_i)};
      """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */")
    stream.append(f"""typedef struct {{
      {Pointer(self.element)} elements; /**< @private */
      {self.index} size; /**< @private */
    }} {self.name};
    """)


#
class Range(_CollectionRange, DirectAccess):
  
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Pointer(self.iterable, constant=True)} iterable; /**< @private */
          {self.iterable.index} front, back; /**< @private */
        }} {self.name};
      """)

  def _copy(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  def __setup__(self):
    super().__setup__()

    with self.method(self, "new", {"iterable" : self.iterable}) as f:
      f.inline = f"""
        {self} result;
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        result.back = iterable->size;
        return result;
      """

    with self.empty as f:
      f.inline = f"""
        assert(target);
        return target->front >= target->back;
      """

    with self.front as f:
      f.inline = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->front")};
      """

    with self.front_view as f:
      f.inline = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->front")};
      """

    with self.move_front as f:
      f.inline = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        ++target->front;
      """

    with self.back as f:
      f.inline = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->back-1")};
      """

    with self.back_view as f:
      f.inline = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->back-1")};
      """

    with self.move_back as f:
      f.inline = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        --target->back;
      """

    with self.get as f:
      f.inline = lambda: f"""
      assert(target);
      return {self.iterable.get("target->iterable", "target->front + index")};
    """

    with self.view as f:
      f.inline = lambda: f"""
        assert(target);
        return {self.iterable.view("target->iterable", "target->front + index")};
      """

    with self.size as f:
      f.inline = f"""
        assert(target);
        assert(target->back >= target->front);
        return target->back - target->front;
      """