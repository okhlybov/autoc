import autoc.std as std
from autoc.hash import XorRot
from autoc.map import Map
from autoc.sortable import Sortable
from autoc.sequence import Sequence
from autoc.range import DirectAccess
from autoc.collection import _Range
from autoc.core import out, inout, Callable, Indirection, _StructRenderer


#
class Array(_StructRenderer, Map, Sortable, Sequence):

  brief = "Fixed-size stack-allocated contiguous sequence container"

  def __init__(self, name, element, size, *args, sorting_operations=True, hasher=XorRot(), dependencies=(), **kws):
    self._size = int(size)
    if self._size < 1:
      raise ValueError(f"Array size must be at least 1, got {self._size}")
    super().__init__(name, element, std.size_t, *args, sorting_operations=sorting_operations, hasher=hasher, dependencies=(*dependencies, std.assert_h, std.string_h), **kws)
    self.range = Range(self)

  @property
  def constructible(self):
    return True

  @property
  def default_constructible(self):
    return self.element.default_constructible or self.element.zero_initializable

  @property
  def destructible(self):
    return self.element.destructible

  @property
  def copyable(self):
    return self.element.copyable

  @property
  def moveable(self):
    return self.element.moveable

  @property
  def swappable(self):
    return self.element.swappable

  @property
  def comparable(self):
    return self.element.comparable

  @property
  def orderable(self):
    return False

  @property
  def hashable(self):
    return self.element.hashable

  @property
  def zero_initializable(self):
    return self.element.zero_initializable

  def _element_c(self, target, index):
    return self.element.variable(f"{target}->elements[{index}]")

  def _size_c(self, target):
    return str(self._size)

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self.element} elements[{self._size}]; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Fixed-size direct access sequence container holding exactly {self._size} elements.
      Allocates no dynamic heap memory, storing elements inline in a contiguous C array.
      Supports bidirectional element traversal via the corresponding @ref {self.range} iterator
      as well as direct indexed access to its elements.

      The closest C++ equivalent is [std::array<>](https://en.cppreference.com/w/cpp/container/array).
    """

    target_i = self.element.variable("target->elements[index]")
    source_i = self.element.variable("source->elements[index]")
    left_i = self.element.variable("left->elements[index]")
    right_i = self.element.variable("right->elements[index]")

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return 0;
      """

    with self.size as f:
      f.inline_code = f"""
        assert(target);
        return {self._size};
      """

    with self.indexed as f:
      f.inline_code = f"""
        assert(target);
        return {f.index} < {self._size};
      """

    with self.create as f:
      if self.element.zero_initializable:
        f.inline_code = f"""
          assert(target);
          memset(target->elements, 0, sizeof(target->elements));
        """
      else:
        f.code = f"""
          size_t index;
          assert(target);
          for(index = 0; index < {self._size}; ++index) {{
            {self.element.create(target_i)};
          }}
        """

    with self.method(None, "fill", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable, brief="Fill all array elements with a copy of the given value",
      description="""
        Assigns the given value to every element of the array. Previous elements are destroyed if needed.

        @param[in,out] target the array to fill
        @param[in] element the value to assign to every position
      """) as f:
      destroy_i = self.element.destroy(target_i) if self.element.destructible else ""
      f.code = f"""
        size_t index;
        assert(target);
        for(index = 0; index < {self._size}; ++index) {{
          {destroy_i};
          {self.element.copy(target_i, f.element)};
        }}
      """

    if self.destructible:
      with self.destroy as f:
        f.code = f"""
          size_t index;
          assert(target);
          for(index = 0; index < {self._size}; ++index) {{
            {self.element.destroy(target_i)};
          }}
        """

    with self.copy as f:
      f.code = f"""
        size_t index;
        assert(target);
        assert(source);
        for(index = 0; index < {self._size}; ++index) {{
          {self.element.copy(target_i, source_i)};
        }}
      """

    with self.move as f:
      f.code = f"""
        size_t index;
        assert(target);
        assert(source);
        for(index = 0; index < {self._size}; ++index) {{
          {self.element.move(target_i, source_i)};
        }}
      """

    with self.swap as f:
      f.code = f"""
        size_t index;
        assert(left);
        assert(right);
        for(index = 0; index < {self._size}; ++index) {{
          {self.element.swap(left_i, right_i)};
        }}
      """

    if self.comparable:
      with self.equal as f:
        f.code = f"""
          size_t index;
          assert(left);
          assert(right);
          for(index = 0; index < {self._size}; ++index) {{
            if(!{self.element.equal(left_i, right_i)}) return 0;
          }}
          return 1;
        """

    with self.get as f:
      result = f.result.variable("result")
      slot = self.element.variable(f"target->elements[{f.index}]")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {self.element.copy(result, slot)};
        return {result};
      """

    with self.view as f:
      slot = self.element.variable(f"target->elements[{f.index}]")
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        return {slot.bind(f.result)};
      """

    with self.set as f:
      slot = self.element.variable(f"target->elements[{f.index}]")
      destroy_slot = self.element.destroy(slot) if self.element.destructible else ""
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {destroy_slot};
        {self.element.copy(slot, f.element)};
      """

    with self.method(self.element, "front", {"target": self}, constraint=lambda: self.element.copyable,
      references=(self.get,),
      brief="Get a copy of the front element",
      description="""
        Returns a copy of the first element in the array.

        @param[in] target the array to read from
        @return a copy of the first element
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self.get(f.target, 0)};
      """

    with self.method(self.element.view_type, ("front", "view"), {"target": self},
      references=(self.view,),
      brief="Get a constant view of the front element",
      description="""
        Returns a constant view of the first element in the array without copying it.

        @param[in] target the array to read from
        @return a constant view of the first element
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self.view(f.target, 0)};
      """

    with self.method(self.element, "back", {"target": self}, constraint=lambda: self.element.copyable,
      references=(self.get,),
      brief="Get a copy of the back element",
      description="""
        Returns a copy of the last element in the array.

        @param[in] target the array to read from
        @return a copy of the last element
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self.get(f.target, self._size - 1)};
      """

    with self.method(self.element.view_type, ("back", "view"), {"target": self},
      references=(self.view,),
      brief="Get a constant view of the back element",
      description="""
        Returns a constant view of the last element in the array without copying it.

        @param[in] target the array to read from
        @return a constant view of the last element
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self.view(f.target, self._size - 1)};
      """

    with self.method(Indirection(self.element), "data", {"target": inout(self)}, brief="Get pointer to the underlying array",
      description="""
        Returns a pointer to the contiguous array storage.

        @param[in,out] target the array to inspect
        @return a pointer to the first element
      """) as f:
      f.inline_code = f"""
        assert(target);
        return target->elements;
      """


#
class Range(_Range, DirectAccess):

  brief = "Direct access range over array"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {Indirection(self.iterable, constant=True)} iterable; /**< @private */
        {self.iterable.index} front, /**< @private */ back; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create range spanning the array",
      description="""
        Creates a range over the array elements. The range must not outlive the array.

        @param[in] iterable the array to span
        @return the range covering the whole array
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        result.back = {self.iterable._size};
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
        return {self.iterable.get("target->iterable", "target->back - 1")};
      """

    with self.back_view as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->back - 1")};
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
