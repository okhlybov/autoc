import autoc.std as std
from autoc.map import Map
from autoc.record import Record
from autoc.variant import Variant
from autoc.sequence import Sequence
from autoc.range import DirectAccess
from autoc.collection import _Range
from autoc.core import out, inout, Callable, Indirection, _StructRenderer


#
class StaticVector(_StructRenderer, Map, Sequence):

  brief = "Fixed-capacity stack-allocated direct access sequence container"

  def __init__(self, name, element, capacity, **kws):
    self._capacity = int(capacity)
    if self._capacity < 1:
      raise ValueError(f"Capacity must be at least 1, got {self._capacity}")
    super().__init__(name, element, std.size_t, **kws)

    self.tuples = []
    for k in range(1, self._capacity + 1):
      fields = {f"_{i}": self.element for i in range(k)}
      t_k = Record(
        self._decorate_component(f"tuple_{k}", abbreviate=False),
        fields,
        visibility="internal",
        getters=False,
        setters=False,
        opaque=False
      )
      self.tuples.append(t_k)
      self.dependencies.add(t_k)

    alternatives = {f"s{k}": self.tuples[k - 1] for k in range(1, self._capacity + 1)}
    self._variant = Variant(
      self._decorate_component("variant", abbreviate=False),
      alternatives,
      visibility="internal"
    )
    self.dependencies.add(self._variant)
    self.range = Range(self)

  @property
  def constructible(self):
    return True

  @property
  def destructible(self):
    return self._variant.destructible

  @property
  def copyable(self):
    return self._variant.copyable

  @property
  def moveable(self):
    return self._variant.moveable

  @property
  def swappable(self):
    return self._variant.swappable

  @property
  def hashable(self):
    return self._variant.hashable

  @property
  def comparable(self):
    return self._variant.comparable

  @property
  def orderable(self):
    return False

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Fixed-capacity direct access sequence container with maximum capacity of {self._capacity} elements.
      Allocates no dynamic heap memory, storing elements inline in an internal tagged union.
      Requires the element type (@ref {self.element}) to be *Copyable*.
      Supports two-way element traversal via the corresponding @ref {self.range} iterator
      as well as subranging with direct indexed access to the subrange's elements.

      Implemented as a tagged union over internal tuple records of length 1 to {self._capacity}.
      The closest C++ equivalent is [std::inplace_vector<>](https://en.cppreference.com/w/cpp/container/inplace_vector) (C++26)
      or [boost::container::static_vector<>](https://www.boost.org/doc/libs/release/doc/html/container/non_standard_containers.html#container.non_standard_containers.static_vector).
    """

    _target = self._variant.variable("target->variant")
    _source = self._variant.variable("source->variant")
    _left = self._variant.variable("left->variant")
    _right = self._variant.variable("right->variant")

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->variant.tag < 0;
      """

    with self.size as f:
      f.inline_code = f"""
        assert(target);
        return (size_t)(target->variant.tag + 1);
      """

    with self.indexed as f:
      f.inline_code = f"""
        assert(target);
        return {f.index} < (size_t)(target->variant.tag + 1);
      """

    with self.method(self.index, "capacity", {"target": self}, brief="Get maximum capacity of static vector",
      description="""
        Returns the maximum number of elements the static vector can hold.

        @param[in] target the static vector to inspect
        @return maximum capacity of the vector
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self._capacity};
      """

    with self.create as f:
      f.inline_code = f"""
        assert(target);
        {self._variant.create(_target)};
      """

    with self.destroy as f:
      if self.destructible:
        f.inline_code = f"""
          assert(target);
          {self._variant.destroy(_target)};
        """
      else:
        f.inline_code = str()

    with self.copy as f:
      f.inline_code = f"""
        assert(target);
        assert(source);
        {self._variant.copy(_target, _source)};
      """

    with self.move as f:
      f.inline_code = f"""
        assert(target);
        assert(source);
        {self._variant.move(_target, _source)};
      """

    with self.equal as f:
      f.inline_code = f"""
        assert(left);
        assert(right);
        return {self._variant.equal(_left, _right)};
      """

    with self.hash as f:
      f.inline_code = f"""
        assert(target);
        return {self._variant.hash(_target)};
      """

    with self.get as f:
      result = f.result.variable("result")
      cases = []
      for i in range(self._capacity):
        slot = f"target->variant.value.s{self._capacity}._{i}"
        slot_var = self.element.variable(slot)
        cases.append(f"case {i}: {{{self.element.copy(result, slot_var)};}} break;")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert({self.indexed(f.target, f.index)});
        switch({f.index}) {{
          {" ".join(cases)}
        }}
        return {result};
      """

    with self.view as f:
      cases = []
      for i in range(self._capacity):
        slot = f"target->variant.value.s{self._capacity}._{i}"
        slot_var = self.element.variable(slot)
        cases.append(f"case {i}: return {slot_var.bind(f.result)};")
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        switch({f.index}) {{
          {" ".join(cases)}
        }}
        return ({self.element.view_type})0;
      """

    with self.set as f:
      cases = []
      for i in range(self._capacity):
        slot = f"target->variant.value.s{self._capacity}._{i}"
        slot_var = self.element.variable(slot)
        destroy_stmt = f"{self.element.destroy(slot_var)};" if self.element.destructible else ""
        cases.append(f"case {i}: {{{destroy_stmt} {self.element.copy(slot_var, f.element)};}} break;")
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        switch({f.index}) {{
          {" ".join(cases)}
        }}
      """

    with self.method(None, "push", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable, brief="Add element to back of static vector",
      description="""
        Appends the element to the back of the static vector in O(1). Asserts that the vector
        has not reached its maximum capacity.

        @param[in,out] target the static vector to add to
        @param[in] element the element to push to the back
      """) as f:
      cases = []
      for i in range(self._capacity):
        slot = f"target->variant.value.s{i+1}._{i}"
        slot_var = self.element.variable(slot)
        cases.append(f"case {i}: {{{self.element.copy(slot_var, f.element)};}} break;")
      f.inline_code = f"""
        assert(target);
        assert(target->variant.tag + 1 < {self._capacity});
        switch(target->variant.tag + 1) {{
          {" ".join(cases)}
        }}
        ++target->variant.tag;
      """

    with self.method(self.element, "pop", {"target": inout(self)}, constraint=lambda: self.element.moveable, brief="Remove and return element from back of static vector",
      description="""
        Removes and returns the back element in O(1). The vector must not be empty.

        @param[in,out] target the static vector to remove from
        @return the removed back element
      """) as f:
      result = f.result.variable("result")
      cases = []
      for i in range(self._capacity):
        slot = f"target->variant.value.s{i+1}._{i}"
        slot_var = self.element.variable(slot)
        destroy_stmt = f"{self.element.destroy(slot_var)};" if self.element.destructible else ""
        cases.append(f"case {i}: {{{self.element.move(result, slot_var)}; {destroy_stmt}}} break;")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(target->variant.tag >= 0);
        switch(target->variant.tag) {{
          {" ".join(cases)}
        }}
        --target->variant.tag;
        return {result};
      """

    with self.method(None, "clear", {"target": inout(self)}, brief="Clear all elements from static vector",
      description="""
        Destroys all elements currently held by the static vector and resets it to the empty state.

        @param[in,out] target the static vector to clear
      """) as f:
      destroy_stmt = f"{self._variant.destroy(_target)};" if self.destructible else ""
      f.inline_code = f"""
        assert(target);
        {destroy_stmt}
        target->variant.tag = -1;
      """

    with self.method(None, ("create", "size"), {"target": out(self), "size": self.index}, constraint=lambda: self.element.default_constructible or self.element.zero_initializable, brief="Create static vector with the given number of default-initialized elements",
      description="""
        Creates the static vector holding exactly the given number of default-initialized elements.
        The size must not exceed the capacity.

        @param[out] target the static vector to construct
        @param[in] size the number of default-initialized elements to create
      """) as f:
      cases = []
      for k in range(1, self._capacity + 1):
        tuple_k = self.tuples[k - 1]
        tuple_var = tuple_k.variable(f"target->variant.value.s{k}")
        cases.append(f"case {k-1}: {{{tuple_k.create(tuple_var)};}} break;")
      f.inline_code = f"""
        assert(target);
        assert({f.size} <= {self._capacity});
        if({f.size} == 0) {{
          target->variant.tag = -1;
        }} else {{
          target->variant.tag = (int){f.size} - 1;
          switch(target->variant.tag) {{
            {" ".join(cases)}
          }}
        }}
      """

    with self.method(self.element, "front", {"target": self}, constraint=lambda: self.element.copyable, brief="Get copy of front element",
      description="""
        Returns a copy of the front element in O(1). The static vector must not be empty.

        @param[in] target the static vector to read
        @return a copy of the front element
      """) as f:
      f.inline_code = f"""
        assert(target);
        assert(target->variant.tag >= 0);
        return {self.get(f.target, "0")};
      """

    with self.method(self.element, "back", {"target": self}, constraint=lambda: self.element.copyable, brief="Get copy of back element",
      description="""
        Returns a copy of the back element in O(1). The static vector must not be empty.

        @param[in] target the static vector to read
        @return a copy of the back element
      """) as f:
      f.inline_code = f"""
        assert(target);
        assert(target->variant.tag >= 0);
        return {self.get(f.target, "(size_t)target->variant.tag")};
      """

    with self.method(self.element.view_type, ("front", "view"), {"target": self}, brief="Get view of front element",
      description="""
        Returns a pointer to the front element in O(1) without copying it.
        The static vector must not be empty.

        @param[in] target the static vector to read
        @return a constant view of the front element
      """) as f:
      f.inline_code = f"""
        assert(target);
        assert(target->variant.tag >= 0);
        return {self.view(f.target, "0")};
      """

    with self.method(self.element.view_type, ("back", "view"), {"target": self}, brief="Get view of back element",
      description="""
        Returns a pointer to the back element in O(1) without copying it.
        The static vector must not be empty.

        @param[in] target the static vector to read
        @return a constant view of the back element
      """) as f:
      f.inline_code = f"""
        assert(target);
        assert(target->variant.tag >= 0);
        return {self.view(f.target, "(size_t)target->variant.tag")};
      """

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      typedef struct {{
        {self._variant.variable("variant").definition}; /**< @private */
      }} {self.name};
    """)


#
class Range(_Range, DirectAccess):

  brief = "Direct access range over static vector"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      typedef struct {{
        {Indirection(self.iterable, constant=True)} iterable; /**< @private */
        {self.iterable.index} front, /**< @private */ back; /**< @private */
      }} {self.name};
    """)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create range spanning the static vector",
      description="""
        Creates a range over the static vector elements. The range must not outlive the vector.

        @param[in] iterable the static vector to span
        @return the range covering the static vector
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        result.back = (size_t)(iterable->variant.tag + 1);
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
