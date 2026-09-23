import autoc.std as std
from autoc.map import Map
from autoc.sequence import Sequence
from autoc.range import DirectAccess
from autoc.collection import _Range
from autoc.core import out, inout, Macro, Callable, Indirection, _StructRenderer


#
class Vector(_StructRenderer, Map, Sequence):

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
            target->storage.heap_elements = {self.memory.allocate(self.element, f.capacity)}; assert(target->storage.heap_elements);
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
            target->elements = {self.memory.allocate(self.element, f.capacity)}; assert(target->elements);
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
              target->storage.heap_elements = {self.memory.allocate(self.element, f.size, zero=True)}; assert(target->storage.heap_elements);
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
              target->elements = {self.memory.allocate(self.element, f.size, zero=True)}; assert(target->elements);
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
              elements = {self.memory.allocate(self.element, f.size, zero=True)}; assert(elements);
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
              elements = {self.memory.allocate(self.element, f.size)}; assert(elements);
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
          elements = {self.memory.allocate(self.element, "new_capacity")}; assert(elements);
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

    # Sorting is defined for the orderable, copyable and swappable element types: the sort exchanges
    # the elements so it requires swappability in addition to orderability while the pivot is still
    # copied out so the copyability is required as well. The algorithm is a quicksort with the
    # median-of-three pivot and the insertion sort applied to the small ranges. The swap based
    # implementation leverages the element's swappability: swapping exchanges the representations of
    # two complete values so both sides remain valid afterwards - unlike move it requires no pristine
    # state to be left behind.
    # The bodies are constructed lazily because they call the element operations which are inactive
    # for the types the respective constraints disallow
    sort_constraint = lambda: self.element.orderable and self.element.copyable and self.element.swappable

    element_i = self.element.variable(f"{data}[i]")
    element_j = self.element.variable(f"{data}[j]")
    element_lo = self.element.variable(f"{data}[lo]")
    element_mid = self.element.variable(f"{data}[mid]")
    element_hi = self.element.variable(f"{data}[hi]")
    element_prev = self.element.variable(f"{data}[j-1]")
    pivot = self.element.variable("pivot")

    with self.method(None, ("sort", "insertion"), {"target": inout(self), "lo": self.index, "hi": self.index}, hidden=True, visibility="internal", constraint=sort_constraint, brief="Sort range using insertion sort (internal)") as f:
      f.code = lambda f=f: f"""
        size_t i, j;
        assert(target);
        for(i = {f.lo} + 1; i <= {f.hi}; ++i) {{
          for(j = i; j > {f.lo} && {self.element.compare(element_prev, element_j)} > 0; --j) {{
            {self.element.swap(element_prev, element_j)};
          }}
        }}
      """

    with self.method(None, ("sort", "range"), {"target": inout(self), "lo": self.index, "hi": self.index}, hidden=True, visibility="internal", constraint=sort_constraint, brief="Sort range using quicksort (internal)") as f:
      f.code = lambda f=f: f"""
        size_t i, j, mid;
        {pivot.definition};
        assert(target);
        while({f.lo} < {f.hi}) {{
          if({f.hi} - {f.lo} < 16) {{ /* small ranges are insertion sorted */
            {self.sort_insertion(f.target, f.lo, f.hi)};
            return;
          }}
          mid = {f.lo} + ({f.hi} - {f.lo})/2;
          /* median of three orders the lo, mid and hi elements protecting against the sorted inputs */
          if({self.element.compare(element_mid, element_lo)} < 0) {self.element.swap(element_mid, element_lo)};
          if({self.element.compare(element_hi, element_mid)} < 0) {{
            {self.element.swap(element_hi, element_mid)};
            if({self.element.compare(element_mid, element_lo)} < 0) {self.element.swap(element_mid, element_lo)};
          }}
          {self.element.copy(pivot, element_mid)};
          i = {f.lo};
          j = {f.hi};
          while(i <= j) {{
            while({self.element.compare(element_i, pivot)} < 0) ++i;
            while({self.element.compare(element_j, pivot)} > 0) --j;
            if(i >= j) break;
            {self.element.swap(element_i, element_j)};
            ++i;
            --j;
          }}
          {str(self.element.destroy(pivot)) + ";" if self.element.destructible else str()}
          /* recursing into the smaller part and iterating over the larger one bounds the recursion depth */
          if(j - {f.lo} < {f.hi} - i) {{
            {self.sort_range(f.target, f.lo, "j")};
            {f.lo} = i;
          }} else {{
            {self.sort_range(f.target, "i", f.hi)};
            {f.hi} = j;
          }}
        }}
      """

    with self.method(None, "sort", {"target": inout(self)}, constraint=sort_constraint, brief="Sort elements in ascending order",
      description="""
        Sorts the elements in ascending order in expected O(n log n) with a quicksort
        variant: ranges of less than 16 elements are insertion sorted, the pivot is the
        median of three which protects against the sorted inputs, and the recursion always
        descends into the smaller part to bound the depth. The sort is not stable and needs
        the element to be Orderable, Copyable and Swappable.

        @param[in,out] target the vector to sort
      """) as f:
      f.code = lambda f=f: f"""
        assert(target);
        if(target->size > 1) {self.sort_range(f.target, 0, "target->size-1")};
      """

    # Reversal is a pure exchange loop so it requires nothing but the element swappability
    with self.method(None, "reverse", {"target": inout(self)}, constraint=lambda: self.element.swappable, brief="Reverse the order of elements",
      description="""
        Reverses the element order in place in O(n) by exchanging the mirrored element
        pairs. It needs nothing but the element swappability - no copies or destructions
        take place.

        @param[in,out] target the vector to reverse
      """) as f:
      f.code = lambda: f"""
        size_t i;
        assert(target);
        for(i = 0; i < target->size/2; ++i) {self.element.swap(self.element.variable(f"{data}[i]"), self.element.variable(f"{data}[target->size-1-i]"))};
      """

    with self.method("int", ("is", "sorted"), {"target": self}, constraint=lambda: self.element.orderable, brief="Check if elements are sorted in ascending order",
      description="""
        Walks the vector once in O(n) returning non-zero when every element is not less
        than its predecessor. An empty or single element vector is considered sorted.

        @param[in] target the vector to check
        @return non-zero if the elements are sorted in ascending order
      """) as f:
      f.code = lambda: f"""
        size_t index;
        assert(target);
        for(index = 1; index < target->size; ++index) {{
          if({self.element.compare(self.element.variable(f"{data}[index]"), self.element.variable(f"{data}[index-1]"))} < 0) return 0;
        }}
        return 1;
      """

    # The binary search operations require the vector sorted in the ascending order
    with self.method(std.size_t, ("lower", "bound"), {"target": self, "element": self.element}, constraint=lambda: self.element.orderable, brief="Get the first position the element can be inserted at keeping the order",
      description="""
        Binary searches the sorted vector in O(log n) returning the leftmost position the
        element can be inserted at keeping the ascending order. The vector must be sorted
        in the ascending order beforehand.

        @param[in] target the sorted vector to search
        @param[in] element the element to insert
        @return the position of the first element not less than the given one
      """) as f:
      f.code = lambda f=f: f"""
        size_t low, high, mid;
        assert(target);
        low = 0;
        high = target->size;
        while(low < high) {{
          mid = low + (high - low)/2;
          if({self.element.compare(self.element.variable(f"{data}[mid]"), f.element)} < 0) low = mid + 1;
          else high = mid;
        }}
        return low;
      """

    with self.method(std.size_t, ("upper", "bound"), {"target": self, "element": self.element}, constraint=lambda: self.element.orderable, brief="Get the last position the element can be inserted at keeping the order",
      description="""
        Binary searches the sorted vector in O(log n) returning the rightmost position the
        element can be inserted at keeping the ascending order. The vector must be sorted
        in the ascending order beforehand.

        @param[in] target the sorted vector to search
        @param[in] element the element to compare with
        @return the position of the first element greater than the given one
      """) as f:
      f.code = lambda f=f: f"""
        size_t low, high, mid;
        assert(target);
        low = 0;
        high = target->size;
        while(low < high) {{
          mid = low + (high - low)/2;
          if({self.element.compare(self.element.variable(f"{data}[mid]"), f.element)} <= 0) low = mid + 1;
          else high = mid;
        }}
        return low;
      """

    with self.method("int", ("binary", "search"), {"target": self, "element": self.element}, constraint=lambda: self.element.orderable, brief="Check if the element is present in the sorted vector",
      description="""
        Binary searches the sorted vector in O(log n) for the element. The vector must be
        sorted in the ascending order beforehand.

        @param[in] target the sorted vector to search
        @param[in] element the element to look for
        @return non-zero if the element is present in the vector
      """) as f:
      f.code = lambda f=f: f"""
        size_t low;
        assert(target);
        low = {self.lower_bound(f.target, f.element)};
        return low < target->size && !{self.element.compare(self.element.variable(f"{data}[low]"), f.element)};
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