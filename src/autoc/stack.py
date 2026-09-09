from autoc.list import List
from autoc.collection import Collection
from autoc.core import _StructRenderer, Callable
from autoc.core import inout


#
class Stack(_StructRenderer, Collection):

  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self._list = List(self._decorate_component("list", abbreviate=False), self.element, visibility="internal")
    self.dependencies.add(self._list)

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

    with self.contains as f:
      f.code = f"""
        assert(target);
        return {self._list.contains(_target, f.element)};
      """

    with self.hash as f:
      f.code = f"""
        assert(target);
        return {self._list.hash(_target)};
      """

    with self.method(None, "push", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable) as f:
      f.code = f"""
        assert(target);
        {self._list.push_front(_target, f.element)};
      """

    with self.method(self.element, "pop", {"target": inout(self)}, constraint=lambda: self.element.moveable) as f:
      f.code = f"""
        assert(target);
        return {self._list.pop_front(_target)};
      """

    with self.method(self.element, "top", {"target": self}, constraint=lambda: self.element.copyable) as f:
      f.code = f"""
        assert(target);
        return {self._list.front(_target)};
      """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self._list.variable("list").definition}; /**< @private */
    }} {self.name};
    """)