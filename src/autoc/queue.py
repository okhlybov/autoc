from autoc.deque import Deque
from autoc.range import Forward
from autoc.collection import Collection, Range as _Range
from autoc.core import _StructRenderer, Callable, Indirection, inout


#
class Queue(_StructRenderer, Collection):

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self._deque = Deque(self._decorate_component("deque"), self.element, visibility="internal")
    self.dependencies.add(self._deque)

  @property
  def orderable(self):
    return False

  def __setup__(self):
    super().__setup__()

    _target = self._deque.variable("target->deque")
    _source = self._deque.variable("source->deque")
    _left = self._deque.variable("left->deque")
    _right = self._deque.variable("right->deque")

    with self.empty as f:
      f.code = f"""
        assert(target);
        return {self._deque.empty(_target)};
      """

    with self.size as f:
      f.code = f"""
        assert(target);
        return {self._deque.size(_target)};
      """

    with self.create as f:
      f.code = f"""
        assert(target);
        {self._deque.create(_target)};
      """

    with self.destroy as f:
      f.code = f"""
        assert(target);
        {self._deque.destroy(_target)};
      """

    with self.copy as f:
      f.code = f"""
        assert(target);
        assert(source);
        {self._deque.copy(_target, _source)};
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        {self._deque.move(_target, _source)};
      """

    with self.equal as f:
      f.code = f"""
        assert(left);
        assert(right);
        return {self._deque.equal(_left, _right)};
      """

    with self.hash as f:
      f.code = f"""
        assert(target);
        return {self._deque.hash(_target)};
      """

    with self.contains as f:
      f.code = f"""
        assert(target);
        return {self._deque.contains(_target, f.element)};
      """

    with self.method(None, "enqueue", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable) as f:
      f.code = f"""
        assert(target);
        {self._deque.push_back(_target, f.element)};
      """

    with self.method(self.element, "dequeue", {"target": inout(self)}, constraint=lambda: self.element.moveable) as f:
      f.code = f"""
        assert(target);
        return {self._deque.pop_front(_target)};
      """

    with self.method(self.element, "front", {"target": self}, constraint=lambda: self.element.copyable) as f:
      f.code = f"""
        assert(target);
        return {self._deque.front(_target)};
      """

    with self.method(self.element, "back", {"target": self}, constraint=lambda: self.element.copyable) as f:
      f.code = f"""
        assert(target);
        return {self._deque.back(_target)};
      """

    self.range = Range(self)

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self._deque.variable("deque").definition}; /**< @private */
    }} {self.name};
    """)


#
class Range(_Range, Forward):

  # The range traverses the queue in FIFO order - from front to back

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Indirection(self.iterable, constant=True)} iterable; /**< @private */
          {self.iterable._deque.node}* front; /**< @private */
          {self.iterable._deque.node}* back; /**< @private */
        }} {self.name};
      """)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.front = iterable->deque.front;
        result.back = iterable->deque.back;
        return {result};
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return !target->front || !target->back || target->front == target->back->next;
      """

    front_element = self.iterable.element.variable("target->front->element")

    with self.front as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, front_element)};
        return {result};
      """

    with self.front_view as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {front_element.bind(f.result)};
      """

    with self.move_front as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        target->front = target->front->next;
      """
