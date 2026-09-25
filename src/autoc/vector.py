import autoc.std as std
from autoc.map import Map
from autoc.sortable import Sortable
from autoc.sequence import Sequence
from autoc.range import DirectAccess
from autoc.collection import _Range
from autoc.core import out, inout, Macro, Callable, Indirection, _StructRenderer


#
class Vector(_StructRenderer, Map, Sortable, Sequence):

  brief = "Direct access sequence container"
  
  def __init__(self, name, element, inline_capacity=0, *args, dependencies=(), **kws):
    self.inline_capacity = int(inline_capacity)
    if self.inline_capacity < 0:
      raise ValueError(f"Vector inline_capacity must be non-negative, got {self.inline_capacity}")
    super().__init__(name, element, std.size_t, *args, dependencies=(*dependencies, std.string_h), **kws)
    self.range = Range(self)

  def _data(self, target):
    if self.inline_capacity > 0:
      return f"({target}->capacity <= {self.inline_capacity} ? {target}->storage.inline_elements : {target}->storage.heap_elements)"
    return f"({target}->elements)"

  def _free_heap(self, target):
    if self.inline_capacity > 0:
      return f"if({target}->capacity > {self.inline_capacity}) {{ {self.memory.free(f'{target}->storage.heap_elements')}; }}"
    return f"if({target}->elements) {{ {self.memory.free(f'{target}->elements')}; }}"

  def _set_heap(self, target, ptr, capacity):
    if self.inline_capacity > 0:
      return f"{target}->storage.heap_elements = {ptr}; {target}->capacity = {capacity};"
    return f"{target}->elements = {ptr}; {target}->capacity = {capacity};"

  def _element_c(self, target, index):
    return self.element.variable(f"{self._data(target)}[{index}]")

  def __setup__(self):
    super().__setup__()
    
    self.description = f"""
      Requires the element type (@ref {self.element}) to be *DefaultConstructible* and *Copyable*.
      Supports bidirectional element traversal via the corresponding @ref {self.range} iterator as well as subranging with direct indexed access to the subrange's elements.

      Implemented as the contiguous array of elements.
      {"Supports small buffer optimization (SBO) with inline capacity of " + str(self.inline_capacity) + " elements avoiding heap allocations until exceeded." if self.inline_capacity > 0 else "Dynamically allocates contiguous element storage on the heap."}
      The closest C++ equivalent is [std::vector<>](https://cppreference.com/cpp/container/vector).
    """

    data = self._data("target")
    left_i = self.element.variable(f"{self._data('left')}[index]")
    right_i = self.element.variable(f"{self._data('right')}[index]")
    source_i = self.element.variable(f"{self._data('source')}[index]")
    target_i = self.element.variable(f"{data}[index]")

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->size == 0;
      """
    
    with self.indexed as f:
      f.inline_code = f"""
        assert(target);
        return index < target->size;
      """
    
    with self.size as f:
      f.inline_code = f"""
        assert(target);
        return target->size;
      """

    with self.method(self.index, "capacity", {"target": self}, brief="Get the current allocated capacity",
      description="""
        Returns the number of elements the vector can hold without reallocating storage.

        @param[in] target the vector to query
        @return the current capacity
      """) as f:
      f.inline_code = f"""
        assert(target);
        return target->capacity;
      """

    with self.method(Indirection(self.element), "data", {"target": inout(self)}, brief="Get pointer to the contiguous element buffer",
      description="""
        Returns a pointer to the contiguous element buffer. The pointer remains valid
        until the vector is resized, reallocated by push, or destroyed.

        @param[in,out] target the vector to query
        @return pointer to the first element
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {data};
      """
    
    with self.method(None, "allocate", {"target": out(self), "capacity": self.index}, visibility="private", brief="Allocate the element storage with given capacity (private)") as f:
      if self.inline_capacity > 0:
        f.code = f"""
          assert(target);
          if({f.capacity} > {self.inline_capacity}) {{
            target->storage.heap_elements = {self.memory.allocate(self.element, f.capacity)};
            target->capacity = {f.capacity};
          }} else {{
            target->capacity = {self.inline_capacity};
          }}
          target->size = {f.capacity};
        """
      else:
        f.code = f"""
          assert(target);
          if({f.capacity} > 0) {{
            target->elements = {self.memory.allocate(self.element, f.capacity)};
            target->capacity = {f.capacity};
          }} else {{
            target->elements = NULL;
            target->capacity = 0;
          }}
          target->size = {f.capacity};
        """
    
    # The zero initializable elements are default initialized by the zeroed allocation alone
    with self.method(None, ("create", "size"), {"target": out(self), "size": self.index}, constraint=lambda: self.element.default_constructible or self.element.zero_initializable, brief="Create vector with the given number of default-initialized elements",
      description="""
        Creates the vector holding exactly the given number of default-initialized elements.
        Zero-initializable elements are initialized by the zeroed buffer allocation alone;
        otherwise each element is default constructed in place over the freshly allocated buffer.

        @param[out] target the vector to construct
        @param[in] size the number of default-initialized elements to create
      """) as f:
      if self.element.zero_initializable:
        if self.inline_capacity > 0:
          f.code = f"""
            assert(target);
            if({f.size} > {self.inline_capacity}) {{
              target->storage.heap_elements = {self.memory.allocate(self.element, f.size, zero=True)};
              target->capacity = {f.size};
            }} else {{
              memset(target->storage.inline_elements, 0, {f.size} * sizeof({self.element}));
              target->capacity = {self.inline_capacity};
            }}
            target->size = {f.size};
          """
        else:
          f.code = f"""
            assert(target);
            if({f.size} > 0) {{
              target->elements = {self.memory.allocate(self.element, f.size, zero=True)};
              target->capacity = {f.size};
            }} else {{
              target->elements = NULL;
              target->capacity = 0;
            }}
            target->size = {f.size};
          """
      else:
        f.code = f"""
          {self.index} index;
          assert(target);
          {self.allocate(*f.arguments)};
          for(index = 0; index < {f.size}; ++index) {self.element.create(target_i)};
        """

    with self.get as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {self.element.copy(result, target_i)};
        return {result};
      """
    
    # FIXME explicit casting here and ithere in the respective Range type is a kind of hack to deal with double pointer types
    # Normally Pointer type should be responsible for handling the per-indirection constness flags
    
    with self.view as f:
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        return {target_i.bind(f.result)};
      """

    destroy_i = self.element.destroy(target_i) if self.element.destructible else str()
    
    with self.set as f:
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {destroy_i};
        {self.element.copy(target_i, f.element)};
      """

    # Resize follows the std::vector::resize semantics: growing default-initializes the
    # new tail elements while shrinking destroys the removed tail. Growing reallocates
    # the exact size buffer and migrates the old elements by copy; shrinking only
    # destroys the tail since the buffer is a single allocation freed as a whole
    with self.method(None, "resize", {"target": inout(self), "size": self.index}, constraint=lambda: self.element.copyable and (self.element.default_constructible or self.element.zero_initializable), brief="Resize the vector to the given number of elements",
      description="""
        Changes the number of elements following the std::vector::resize semantics: growing appends
        default-initialized elements while shrinking destroys the removed tail.
        Growing reallocates the exact size buffer and migrates the old elements by copy, so the
        element pointers into the vector do not survive it; shrinking keeps the allocation and
        only destroys the tail since the buffer is a single allocation freed as a whole.

        @param[in,out] target the vector to resize
        @param[in] size the new number of elements - the tail is destroyed when shrinking and default-initialized when growing
      """) as f:
      if self.element.zero_initializable:
        f.code = f"""
          {self.index} index;
          assert(target);
          if({f.size} > target->size) {{
            if({f.size} > target->capacity) {{
              {Indirection(self.element)} elements;
              elements = {self.memory.allocate(self.element, f.size, zero=True)};
              for(index = 0; index < target->size; ++index) {{
                {self.element.copy(self.element.variable("elements[index]"), target_i)};
                {destroy_i};
              }}
              {self._free_heap("target")}
              {self._set_heap("target", "elements", f.size)}
            }} else {{
              memset(&({data}[target->size]), 0, ({f.size} - target->size) * sizeof({self.element}));
            }}
          }} else {{
            for(index = {f.size}; index < target->size; ++index) {{
              {destroy_i};
            }}
          }}
          target->size = {f.size};
        """
      else:
        f.code = f"""
          {self.index} index;
          assert(target);
          if({f.size} > target->size) {{
            if({f.size} > target->capacity) {{
              {Indirection(self.element)} elements;
              elements = {self.memory.allocate(self.element, f.size)};
              for(index = 0; index < target->size; ++index) {{
                {self.element.copy(self.element.variable("elements[index]"), target_i)};
                {destroy_i};
              }}
              {self._free_heap("target")}
              {self._set_heap("target", "elements", f.size)}
            }}
            for(index = target->size; index < {f.size}; ++index) {{
              {self.element.create(target_i)};
            }}
          }} else {{
            for(index = {f.size}; index < target->size; ++index) {{
              {destroy_i};
            }}
          }}
          target->size = {f.size};
        """

    with self.method(None, "push", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable, brief="Add element to back",
      description="""
        Appends the element to the back in amortized O(1), reallocating the buffer with geometric
        doubling when the capacity is exhausted.

        @param[in,out] target the vector to add to
        @param[in] element the element to add to the back
      """) as f:
      f.code = f"""
        assert(target);
        if(target->size == target->capacity) {{
          {self.index} index, new_capacity;
          {Indirection(self.element)} elements;
          new_capacity = target->capacity == 0 ? 8 : target->capacity * 2;
          elements = {self.memory.allocate(self.element, "new_capacity")};
          for(index = 0; index < target->size; ++index) {{
            {self.element.copy(self.element.variable("elements[index]"), target_i)};
            {destroy_i};
          }}
          {self._free_heap("target")}
          {self._set_heap("target", "elements", "new_capacity")}
        }}
        {self.element.copy(self.element.variable(f"{data}[target->size]"), f.element)};
        ++target->size;
      """

    with self.method(self.element, "pop", {"target": inout(self)}, constraint=lambda: self.element.moveable, brief="Remove and return element from back",
      description="""
        Removes and returns the back element in O(1). The vector must not be empty.

        @param[in,out] target the vector to remove from - must not be empty
        @return the removed back element
      """) as f:
      result = f.result.variable("result")
      last_i = self.element.variable(f"{data}[target->size]")
      destroy_last = f"{self.element.destroy(last_i)};" if self.element.destructible else ""
      f.code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        --target->size;
        {self.element.move(result, last_i)};
        {destroy_last}
        return {result};
      """

    with self.method(None, "compact", {"target": inout(self)}, constraint=lambda: self.element.copyable, brief="Compact buffer capacity to fit element count",
      description="""
        Reduces the allocated capacity down to the current size. If the vector has inline capacity
        and the current element count fits within it, dynamic heap memory is freed and the elements
        revert to the inlined buffer.

        @param[in,out] target the vector to compact
      """) as f:
      destroy_heap_i = str(self.element.destroy(self.element.variable("heap[index]"))) + ";" if self.element.destructible else str()
      if self.inline_capacity > 0:
        f.code = f"""
          {self.index} index;
          assert(target);
          if(target->capacity > {self.inline_capacity}) {{
            if(target->size <= {self.inline_capacity}) {{
              {Indirection(self.element)} heap = target->storage.heap_elements;
              for(index = 0; index < target->size; ++index) {{
                {self.element.copy(self.element.variable("target->storage.inline_elements[index]"), self.element.variable("heap[index]"))};
                {destroy_heap_i}
              }}
              {self.memory.free("heap")};
              target->capacity = {self.inline_capacity};
            }} else if(target->size < target->capacity) {{
              {Indirection(self.element)} elements = {self.memory.allocate(self.element, "target->size")};
              for(index = 0; index < target->size; ++index) {{
                {self.element.copy(self.element.variable("elements[index]"), target_i)};
                {destroy_i};
              }}
              {self.memory.free("target->storage.heap_elements")};
              target->storage.heap_elements = elements;
              target->capacity = target->size;
            }}
          }}
        """
      else:
        f.code = f"""
          {self.index} index;
          assert(target);
          if(target->size == 0) {{
            if(target->elements) {{
              {self.memory.free("target->elements")};
              target->elements = NULL;
            }}
            target->capacity = 0;
          }} else if(target->size < target->capacity) {{
            {Indirection(self.element)} elements = {self.memory.allocate(self.element, "target->size")};
            for(index = 0; index < target->size; ++index) {{
              {self.element.copy(self.element.variable("elements[index]"), target_i)};
              {destroy_i};
            }}
            {self.memory.free("target->elements")};
            target->elements = elements;
            target->capacity = target->size;
          }}
        """

    with self.create as f:
      if self.inline_capacity > 0:
        f.inline_code = f"""
          assert(target);
          target->size = 0;
          target->capacity = {self.inline_capacity};
        """
      else:
        f.inline_code = """
          assert(target);
          target->elements = NULL;
          target->size = 0;
          target->capacity = 0;
        """
    
    with self.destroy as f:
      destroy_loop = f"""
        {self.index} index;
        if(target->size > 0) {{
          for(index = 0; index < target->size; ++index) {self.element.destroy(target_i)};
        }}
      """ if self.element.destructible else ""
      f.code = f"""
        assert(target);
        {destroy_loop}
        {self._free_heap("target")}
      """

    # FIXME should come from sequence    
    if self.comparable:
      with self.equal as f:
        f.code = f"""
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
      f.code = f"""
        {self.index} index;
        assert(target);
        assert(source);
        {self.allocate(f.target, "source->size")};
        for(index = 0; index < target->size; ++index) {self.element.copy(target_i, source_i)};
      """

    with self.move as f:
      if self.inline_capacity > 0:
        f.code = f"""
          {self.index} index;
          assert(target);
          assert(source);
          if(source->capacity > {self.inline_capacity}) {{
            target->storage.heap_elements = source->storage.heap_elements;
            target->size = source->size;
            target->capacity = source->capacity;
            {self.create(f.source)};
          }} else {{
            target->size = source->size;
            target->capacity = {self.inline_capacity};
            for(index = 0; index < source->size; ++index) {{
              {self.element.move(target_i, source_i)};
            }}
            {self.create(f.source)};
          }}
        """
      else:
        f.code = f"""
          assert(target);
          assert(source);
          target->elements = source->elements;
          target->size = source->size;
          target->capacity = source->capacity;
          {self.create(f.source)};
        """



  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    if self.inline_capacity > 0:
      stream.append(f"""
        struct {self.name} {{
          {self.index} size; /**< @private */
          {self.index} capacity; /**< @private */
          union {{
            {self.element} inline_elements[{self.inline_capacity}]; /**< @private */
            {Indirection(self.element)} heap_elements; /**< @private */
          }} storage; /**< @private */
        }};
      """)
    else:
      stream.append(f"""
        struct {self.name} {{
          {Indirection(self.element)} elements; /**< @private */
          {self.index} size; /**< @private */
          {self.index} capacity; /**< @private */
        }};
      """)


#
class Range(_Range, DirectAccess):
  
  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {Indirection(self.iterable, constant=True)} iterable; /**< @private */
        {self.iterable.index} front, /**< @private */ back; /**< @private */
      }};
    """)

  def _copy(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable" : self.iterable}, brief="Create the range spanning the whole vector",
      description="""
        Creates the range over the contiguous element buffer. The range must not outlive
        the vector and the vector must not be resized while the range is traversed.

        @param[in] iterable the vector to span
        @return the range covering the whole vector
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        result.back = iterable->size;
        return {result};
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->front >= target->back;
      """

    with self.front as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->front")};
      """

    with self.front_view as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->front")};
      """

    with self.move_front as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        ++target->front;
      """

    with self.back as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->back-1")};
      """

    with self.back_view as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->back-1")};
      """

    with self.move_back as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        --target->back;
      """

    with self.get as f:
      f.inline_code = lambda: f"""
      assert(target);
      return {self.iterable.get("target->iterable", "target->front + index")};
    """

    with self.view as f:
      f.inline_code = lambda: f"""
        assert(target);
        return {self.iterable.view("target->iterable", "target->front + index")};
      """

    with self.size as f:
      f.inline_code = f"""
        assert(target);
        assert(target->back >= target->front);
        return target->back - target->front;
      """