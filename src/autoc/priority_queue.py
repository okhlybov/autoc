import autoc.std as std
from autoc.core import inout, out, Indirection, _StructRenderer, Callable
from autoc.collection import Collection


#
class PriorityQueue(_StructRenderer, Collection):
  # The extraction-ordered container: the elements are consumed in the priority order -
  # top returns the greatest element per the element comparison. The binary heap over the
  # flat array gives the guaranteed O(log n) push/pop with the contiguous cache friendly
  # storage while handling the duplicate priorities naturally. The heap shape is internal:
  # the iteration is not exposed and the equality and the hashing are not defined
  # (two heaps holding the same elements are not required to have the same shape)

  def __init__(self, name, element, **kws):
    super().__init__(name, element, **kws)
    self._element_p = Indirection(self.element)

  def __setup__(self):
    super().__setup__()

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

    with self.method(None, ("create", "capacity"), {"target": out(self), "capacity": std.size_t}) as f:
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

    with self.method(None, "_grow", {"target": inout(self)}, hidden=True, visibility="internal") as f:
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

    with self.method(None, ("sift", "up"), {"target": inout(self), "index": std.size_t}, hidden=True, visibility="internal") as f:
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

    with self.method(None, ("sift", "down"), {"target": inout(self), "index": std.size_t}, hidden=True, visibility="internal") as f:
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

    with self.method(None, "push", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable and self.element.orderable) as f:
      f.code = lambda f=f: f"""
        assert(target);
        if(target->size == target->capacity) {self._grow(f.target)};
        {self.element.copy(slot_size, f.element)};
        ++target->size;
        {self.sift_up(f.target, "target->size - 1")};
      """

    with self.method(self.element, "pop", {"target": inout(self)}, constraint=lambda: self.element.moveable and self.element.orderable) as f:
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

    with self.method(self.element, "top", {"target": self}, constraint=lambda: self.element.copyable and self.element.orderable) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, slot0)};
        return {result};
      """

    with self.method(self.element.view_type, ("top", "view"), {"target": self}, constraint=lambda: self.element.orderable) as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {slot0.bind(f.result)};
      """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self._element_p} elements; /**< @private */
      {std.size_t} capacity; /**< @private */
      {std.size_t} size; /**< @private */
    }} {self.name};
    """)
