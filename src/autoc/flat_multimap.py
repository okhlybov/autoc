import autoc.std as std
from autoc.mapping import _Entry
from autoc.multimap import _Multimap
from autoc.flat_multiset import Set as FlatMultiset
from autoc.core import inout


#
class Map(_Multimap):

  brief = "Flat multimap from index to multiple elements backed by a contiguous sorted array of key-value pairs"

  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, index, *args, **kws)
    self._set = FlatMultiset(
      self._decorate_component("set", abbreviate=True),
      _Entry(self._decorate_component("entry", abbreviate=True), self.element, self.index, visibility="internal"),
      visibility="internal",
      algebraic_operations=False,
    )
    self.dependencies.add(self._set)
    self._setup_range()

  @property
  def orderable(self):
    return True

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the index type (@ref {self.index}) to be *Orderable* and the element type (@ref {self.element}) to be *Copyable*.
      Supports one way traversal over the indices and elements via the corresponding @ref {self.range} iterator - the entries are yielded in index order.
      Multiple entries with equivalent keys are permitted and preserved in FIFO order.

      Implemented as a contiguous sorted array of key-value pairs (Array-of-Structures layout) with binary search lookup.
      Provides O(log n) lookup, O(n) insertion, and superior cache locality over tree-based multimaps.
      The closest C++ equivalent is [std::flat_multimap<>](https://en.cppreference.com/w/cpp/container/flat_multimap) / `boost::container::flat_multimap`.
    """

    _target = self._set.variable("target->set")

    with self.method(std.size_t, "capacity", {"target": self}, brief="Get the current allocated capacity",
      description="""
        Returns the number of key-value entries the multimap can hold without reallocating storage.

        @param[in] target the multimap to query
        @return the current capacity
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self._set.capacity(_target)};
      """

    with self.method(None, "reserve", {"target": inout(self), "capacity": std.size_t}, brief="Reserve storage capacity",
      description="""
        Ensures the multimap has allocated storage for at least the given number of entries.

        @param[in,out] target the multimap to expand
        @param[in] capacity the minimum capacity to reserve
      """) as f:
      f.inline_code = f"""
        assert(target);
        {self._set.reserve(_target, f.capacity)};
      """

    with self.method(None, "compact", {"target": inout(self)}, brief="Compact storage to fit current size",
      description="""
        Reduces the allocated capacity to match the current number of entries.

        @param[in,out] target the multimap to compact
      """) as f:
      f.inline_code = f"""
        assert(target);
        {self._set.compact(_target)};
      """

    with self.compare as f:
      elem_cmp = f"""
        cmp = {self.element.compare(self.element.variable("left->set.elements[i].element"), self.element.variable("right->set.elements[i].element"))};
        if(cmp != 0) return cmp;
      """ if self.element.orderable else ""
      f.code = f"""
        size_t i, min_size;
        int cmp;
        assert(left);
        assert(right);
        min_size = left->set.size < right->set.size ? left->set.size : right->set.size;
        for(i = 0; i < min_size; ++i) {{
          cmp = {self.index.compare(self.index.variable("left->set.elements[i].index"), self.index.variable("right->set.elements[i].index"))};
          if(cmp != 0) return cmp;
          {elem_cmp}
        }}
        return left->set.size < right->set.size ? -1 : (left->set.size > right->set.size ? 1 : 0);
      """
