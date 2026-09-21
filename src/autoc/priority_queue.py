import autoc.std as std
from autoc.collection import Collection
from autoc.core import inout, out, Indirection, _StructRenderer


#
class PriorityQueue(_StructRenderer, Collection):
  # The extraction-ordered container: the elements are consumed in the priority order -
  # top returns the greatest element per the element comparison. The binary heap over the
  # flat array gives the guaranteed O(log n) push/pop with the contiguous cache friendly
  # storage while handling the duplicate priorities naturally. The heap shape is internal:
  # the iteration is not exposed and the equality and the hashing are not defined
  # (two heaps holding the same elements are not required to have the same shape)
  
  brief = "Priority queue of elements ordered by priority"


  def __init__(self, name, element, **kws):
    super().__init__(name, element, **kws)
    self._element_p = Indirection(self.element)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the element type (@ref {self.element}) to be *Orderable*.
      The iteration is not exposed - the elements are consumed one by one via `pop` which
      always yields the greatest element per the element comparison. Duplicate priorities allowed.

      Implemented as the binary heap over the flat array.
      The closest C++ equivalent is [std::priority_queue<>](https://cppreference.com/cpp/container/priority_queue).
    """

    # TODO verify
    # The equality and the hashing are not defined for the heap
    self.equal = None
    self.hash = None
    self.compare = None

    slot0 = self.element.variable("target->elements[0]")
    slot_size = self.element.variable("target->elements[target->size]")

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->size == 0;
      """

    with self.size as f:
      f.inline_code = f"""
        assert(target);
        return target->size;
      """

    with self.create as f:
      f.inline_code = f"""
        assert(target);
        target->elements = NULL;
        target->capacity = target->size = 0;
      """

    with self.method(None, ("create", "capacity"), {"target": out(self), "capacity": std.size_t}, brief="Create the queue with room for the given number of elements",
      description="""
        Creates the queue with the buffer preallocated for the given number of elements -
        no reallocation takes place until the queue grows past it.

        @param[out] target the queue to construct
        @param[in] capacity the number of elements to reserve room for
      """) as f:
      f.code = f"""
        assert(target);
        if({f.capacity} > 0) {{
          target->elements = {self.memory.allocate(self.element, f.capacity)}; assert(target->elements);
        }} else target->elements = NULL;
        target->capacity = {f.capacity};
        target->size = 0;
      """

    with self.destroy as f:
      if self.element.destructible:
        f.code = f"""
          size_t index;
          assert(target);
          if(target->elements) {{
            for(index = 0; index < target->size; ++index) {self.element.destroy(self.element.variable("target->elements[index]"))};
            {self.memory.free("target->elements")};
          }}
        """
      else:
        f.inline_code = f"""
          assert(target);
          if(target->elements) {self.memory.free("target->elements")};
        """

    with self.copy as f:
      f.code = f"""
        size_t index;
        assert(target);
        assert(source);
        target->elements = {self.memory.allocate(self.element, "source->capacity")}; assert(target->elements);
        target->capacity = source->capacity;
        target->size = source->size;
        for(index = 0; index < source->size; ++index) {self.element.copy(self.element.variable("target->elements[index]"), self.element.variable("source->elements[index]"))};
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        target->elements = source->elements;
        target->capacity = source->capacity;
        target->size = source->size;
        {self.create(f.source)};
      """

    with self.contains as f:
      f.code = lambda f=f: f"""
        size_t index;
        assert(target);
        for(index = 0; index < target->size; ++index) {{
          if({self.element.equal(self.element.variable("target->elements[index]"), f.element)}) return 1;
        }}
        return 0;
      """

    with self.method(None, "_grow", {"target": inout(self)}, hidden=True, visibility="internal", brief="Grow internal buffer if needed (internal)") as f:
      f.code = f"""
        size_t index, new_capacity;
        {self._element_p} elements;
        assert(target);
        new_capacity = target->capacity ? target->capacity*2 : 8;
        elements = {self.memory.allocate(self.element, "new_capacity")}; assert(elements);
        for(index = 0; index < target->size; ++index) {self.element.copy(self.element.variable("elements[index]"), self.element.variable("target->elements[index]"))};
        {self.memory.free("target->elements")};
        target->elements = elements;
        target->capacity = new_capacity;
      """

    with self.method(None, ("sift", "up"), {"target": inout(self), "index": std.size_t}, hidden=True, visibility="internal", brief="Sift element up in heap (internal)") as f:
      f.code = lambda f=f: f"""
        size_t parent;
        assert(target);
        while({f.index}) {{
          parent = ({f.index} - 1)/2;
          if({self.element.compare(self.element.variable("target->elements[parent]"), self.element.variable(f"target->elements[{f.index}]"))} >= 0) break;
          {self.element.swap(self.element.variable("target->elements[parent]"), self.element.variable(f"target->elements[{f.index}]"))};
          {f.index} = parent;
        }}
      """

    with self.method(None, ("sift", "down"), {"target": inout(self), "index": std.size_t}, hidden=True, visibility="internal", brief="Sift element down in heap (internal)") as f:
      f.code = lambda f=f: f"""
        size_t child;
        assert(target);
        for(;;) {{
          child = 2*{f.index} + 1;
          if(child >= target->size) break;
          if(child + 1 < target->size && {self.element.compare(self.element.variable("target->elements[child+1]"), self.element.variable("target->elements[child]"))} > 0) ++child;
          if({self.element.compare(self.element.variable(f"target->elements[{f.index}]"), self.element.variable("target->elements[child]"))} >= 0) break;
          {self.element.swap(self.element.variable(f"target->elements[{f.index}]"), self.element.variable("target->elements[child]"))};
          {f.index} = child;
        }}
      """

    with self.method(None, "push", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable and self.element.orderable, brief="Add element to priority queue",
      description="""
        Adds the element to the heap restoring the heap invariant with the O(log n) sift-up.
        The buffer is grown by doubling with element migration when the capacity is exhausted.

        @param[in,out] target the queue to add to
        @param[in] element the element to add
      """) as f:
      f.code = lambda f=f: f"""
        assert(target);
        if(target->size == target->capacity) {self._grow(f.target)};
        {self.element.copy(slot_size, f.element)};
        ++target->size;
        {self.sift_up(f.target, "target->size - 1")};
      """

    with self.method(self.element, "pop", {"target": inout(self)}, constraint=lambda: self.element.moveable and self.element.orderable, brief="Remove and return highest priority element",
      description="""
        Removes and moves out the greatest element per the element comparison in O(log n) -
        the last element replaces the root which is sifted down to restore the heap invariant.
        The returned element is a moved copy so the caller owns it.

        @param[in,out] target the queue to remove from - must not be empty
        @return the highest priority element
      """) as f:
      result = f.result.variable("result")
      f.code = lambda f=f: f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        --target->size;
        {self.element.move(result, slot0)};
        if(target->size) {{
          {self.element.move(slot0, slot_size)};
          {self.sift_down(f.target, 0)};
        }}
        return {result};
      """

    with self.method(self.element, "top", {"target": self}, constraint=lambda: self.element.copyable and self.element.orderable, brief="Get reference to highest priority element",
      description="""
        Returns a copy of the greatest element per the element comparison without
        modifying the heap.

        @param[in] target the queue to read - must not be empty
        @return the highest priority element without removing it
      """) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, slot0)};
        return {result};
      """

    with self.method(self.element.view_type, ("top", "view"), {"target": self}, constraint=lambda: self.element.orderable, brief="Get view of highest priority element",
      description="""
        Returns a pointer to the greatest element per the element comparison without copying
        it. The view is valid until the next `push` or `pop` since the sift operations may
        move the element within the buffer.

        @param[in] target the queue to read - must not be empty
        @return a constant view of the highest priority element
      """) as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {slot0.bind(f.result)};
      """

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      typedef struct {{
        {self._element_p} elements; /**< @private */
        {std.size_t} capacity; /**< @private */
        {std.size_t} size; /**< @private */
      }} {self.name};
    """)
