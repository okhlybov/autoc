import autoc.set
from autoc.flat_sets import _Set


#
class Set(_Set, autoc.set._Set):

  brief = "Contiguous sorted array set with binary search lookup and cache-friendly layout"

  def __init__(self, name, element, *args, **kws):
    super().__init__(name, element, *args, **kws)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the element type (@ref {self.element}) to be *Orderable* and *Copyable*.
      Supports bidirectional element traversal and direct indexed access via the corresponding @ref {self.range} iterator - elements are yielded in ascending order.

      Implemented as a contiguous sorted dynamic array with binary search lookup.
      Provides O(log n) lookup, O(n) insertion and deletion, and superior cache locality over tree-based sets.
      The closest C++ equivalent is [std::flat_set<>](https://en.cppreference.com/w/cpp/container/flat_set) / `boost::container::flat_set`.
    """

    with self.put as f:
      f.references.add(self.lower_bound)
      pos_code = f"""
        size_t pos, i;
        assert(target);
        pos = {self.lower_bound(f.target, f.element)};
        if(pos < target->size && !{self.element.compare(self._element(f.target, "pos"), f.element)}) {{
          return 0;
        }}
      """
      f.code = self._insert_at_code(pos_code, "pos", f.element)
