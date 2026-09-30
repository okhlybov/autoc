import autoc.multiset
import autoc.flat_sets


#
class Set(autoc.flat_sets.Set, autoc.multiset.Multiset):

  brief = "Contiguous sorted array multiset with binary search lookup and cache-friendly layout"

  def __init__(self, name, element, *args, **kws):
    super().__init__(name, element, *args, **kws)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the element type (@ref {self.element}) to be *Orderable* and *Copyable*.
      Supports bidirectional element traversal and direct indexed access via the corresponding @ref {self.range} iterator - elements are yielded in ascending order.
      Multiple duplicate elements with equivalent values are permitted and preserved in order.

      Implemented as a contiguous sorted dynamic array with binary search lookup.
      Provides O(log n) lookup, O(n) insertion and deletion, and superior cache locality over tree-based multisets.
      The closest C++ equivalent is [std::flat_multiset<>](https://en.cppreference.com/w/cpp/container/flat_multiset) / `boost::container::flat_multiset`.
    """

    with self.put as f:
      f.brief = "Insert element into multiset"
      f.description = """
        Inserts the element into the multiset at the upper bound position, keeping equal elements
        in FIFO order.

        @param[in,out] target the multiset to insert into
        @param[in] element the element to insert
        @return always returns 1
      """
      f.references.add(self.upper_bound)
      pos_code = f"""
        size_t pos, i;
        assert(target);
        pos = {self.upper_bound(f.target, f.element)};
      """
      f.code = self._insert_at_code(pos_code, "pos", f.element)

    with self.remove as f:
      f.brief = "Remove one occurrence of element"
      f.description = """
        Removes one occurrence of the element if present, leaving the multiset unchanged otherwise.

        @param[in,out] target the multiset to remove from
        @param[in] element the element to remove
        @return non-zero if an element was removed, zero if absent
      """

    with self.wipe as f:
      f.references.add(self.lower_bound)
      f.references.add(self.upper_bound)
      decl_tail = "size_t start_tail;" if self.element.destructible else ""
      destroy_wipe_range = f"""
        for(i = low; i < high; ++i) {{
          {self.element.destroy(self.element.variable("target->elements[i]"))};
        }}
      """ if self.element.destructible else ""
      destroy_wipe_tail = f"""
        start_tail = target->size - count > high ? target->size - count : high;
        for(i = start_tail; i < target->size; ++i) {{
          {self.element.destroy(self.element.variable("target->elements[i]"))};
        }}
      """ if self.element.destructible else ""
      f.code = f"""
        size_t low, high, count, i;
        {decl_tail}
        assert(target);
        low = {self.lower_bound(f.target, f.element)};
        high = {self.upper_bound(f.target, f.element)};
        count = high - low;
        if(count > 0) {{
          {destroy_wipe_range}
          for(i = high; i < target->size; ++i) {{
            {self.element.move(self.element.variable("target->elements[low + (i - high)]"), self.element.variable("target->elements[i]"))};
          }}
          {destroy_wipe_tail}
          target->size -= count;
        }}
        return count;
      """
