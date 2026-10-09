from autoc.list import List
from autoc.range import Forward
from autoc.sequential import Sequential
from autoc.insertable import Insertable
from autoc.container import _Range
from autoc.core import _StructRenderer, Callable, Indirection, inout, enforced


#
class Stack(_StructRenderer, Sequential, Insertable):

  brief = "Ordered LIFO container with head push/pop"
  
  @enforced
  def _make_list(self, backend: Sequential & Insertable = List):
    return backend(self._decorate_component("list"), self.element, visibility="internal")

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self._list = self._make_list()
    self.dependencies.add(self._list)
    self.range = Range(self)

  @property
  def orderable(self):
    return False

  def __setup__(self):
    super().__setup__()

    _target = self._list.variable("target->list")
    _source = self._list.variable("source->list")
    _left = self._list.variable("left->list")
    _right = self._list.variable("right->list")

    with self.empty as f:
      f.code = f"""
        assert(target);
        return {self._list.empty(_target)};
      """

    with self.size as f:
      f.code = f"""
        assert(target);
        return {self._list.size(_target)};
      """

    with self.create as f:
      f.code = f"""
        assert(target);
        {self._list.create(_target)};
      """

    with self.destroy as f:
      f.code = f"""
        assert(target);
        {self._list.destroy(_target)};
      """

    with self.copy as f:
      f.code = f"""
        assert(target);
        assert(source);
        {self._list.copy(_target, _source)};
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        {self._list.move(_target, _source)};
      """

    with self.equal as f:
      f.code = f"""
        assert(left);
        assert(right);
        return {self._list.equal(_left, _right)};
      """

    with self.find_view as f:
      f.code = f"""
        assert(target);
        return {self._list.find_view(_target, f.element)};
      """

    with self.hash as f:
      f.code = f"""
        assert(target);
        return {self._list.hash(_target)};
      """

    with self.method(None, "push", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable, brief="Add element to top of stack",
      description="""
        Pushes the element onto the top of the stack in O(1) by delegating to the
        internal list. The pushed element becomes the next one returned by `pop`.

        @param[in,out] target the stack to add to
        @param[in] element the element to push onto the top
      """) as f:
      f.code = f"""
        assert(target);
        {self._list.push_front(_target, f.element)};
      """

    with self.method(None, "emplace", {"target": inout(self)} | self.element.constructor_parameters,
      constraint=lambda: self.element.emplaceable, brief="Construct element in-place at top of stack",
      description="""
        Constructs an element in-place with forwarded parameters at the top of the stack in O(1)
        by delegating to the internal list.

        @param[in,out] target the stack to add to
      """) as f:
      create_args = [getattr(f, name) for name in self.element.constructor_parameters]
      f.code = f"""
        assert(target);
        {self._list.emplace_front(_target, *create_args)};
      """

    with self.method(self.element, "pop", {"target": inout(self)}, constraint=lambda: self.element.moveable, brief="Remove and return element from top of stack",
      description="""
        Removes and moves out the top element in O(1) - the element last pushed onto
        the stack. The returned element is a moved copy so the caller owns it.

        @param[in,out] target the stack to remove from - must not be empty
        @return the removed top element
      """) as f:
      f.code = f"""
        assert(target);
        return {self._list.pop_front(_target)};
      """

    with self.method(self.element, "top", {"target": self}, constraint=lambda: self.element.copyable, brief="Get top element",
      description="""
        Returns a copy of the element last pushed onto the stack in O(1) without
        removing it.

        @param[in] target the stack to read - must not be empty
        @return the element at the top without removing it
      """) as f:
      f.code = f"""
        assert(target);
        return {self._list.front(_target)};
      """

    with self.put as f:
      f.inline_code = f"""
        assert(target);
        {self.push(f.target, f.element)};
        return 1;
      """

    with self.remove as f:
      f.code = lambda f=f: f"""
        assert(target);
        return {self._list.remove(_target, f.element)};
      """

    self.description = f"""
      Requires the element type (@ref {self.element}) to be *Copyable*.
      Supports one way element traversal via the corresponding @ref {self.range} iterator.

      Implemented as the LIFO adapter over the internal @ref List.
      The closest C++ equivalent is [std::stack<>](https://cppreference.com/cpp/container/stack).
    """

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._list.variable("list").definition}; /**< @private */
      }};
    """)


#
class Range(_Range, Forward):

  brief = "Forward range over the stack elements"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {Indirection(self.iterable, constant=True)} iterable; /**< @private */
        {self.iterable._list.node}* node; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create the range spanning the whole stack",
      description="""
        Creates the range over the stack elements traversable from the top towards the
        bottom. The range must not outlive the stack and the stack must not be modified
        while the range is traversed.

        @param[in] iterable the stack to span
        @return the range covering the whole stack
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.node = iterable->list.front;
        return {result};
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return !target->node;
      """

    node_element = self.iterable.element.variable("target->node->element")

    with self.front as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, node_element)};
        return {result};
      """

    with self.front_view as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {node_element.bind(f.result)};
      """

    with self.move_front as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        target->node = target->node->next;
      """