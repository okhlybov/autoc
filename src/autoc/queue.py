from autoc.deque import Deque
from autoc.collection import Collection
from autoc.core import _StructRenderer, Callable
from autoc.core import inout


#
class Queue(_StructRenderer, Collection):

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self._deque = Deque(self._decorate_component("deque", abbreviate=False), self.element, visibility="internal")
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

    with self.method(Callable.Parameter(self.element), "dequeue", {"target": inout(self)}, constraint=lambda: self.element.copyable) as f:
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

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self._deque.variable("deque").definition}; /**< @private */
    }} {self.name};
    """)
