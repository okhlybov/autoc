import autoc.std as std
from autoc.core import inout


# Mixin class providing in-place sorting, reversal, and binary search algorithms
# for direct-access sequence containers.
class Sortable:

  def _element_c(self, target, index):
    raise NotImplementedError

  def _size_c(self, target):
    return f"{target}->size"

  def __setup__(self):
    super().__setup__()

    index_type = getattr(self, "index", std.size_t)
    sort_constraint = lambda: self.element.orderable and self.element.copyable and self.element.swappable

    element_i = lambda target="target": self._element_c(target, "i")
    element_j = lambda target="target": self._element_c(target, "j")
    element_lo = lambda target="target": self._element_c(target, "lo")
    element_mid = lambda target="target": self._element_c(target, "mid")
    element_hi = lambda target="target": self._element_c(target, "hi")
    element_prev = lambda target="target": self._element_c(target, "j-1")
    pivot = self.element.variable("pivot")

    with self.method(None, ("sort", "insertion"), {"target": inout(self), "lo": index_type, "hi": index_type}, hidden=True, visibility="internal", constraint=sort_constraint, brief="Sort range using insertion sort (internal)") as f:
      f.code = lambda f=f: f"""
        size_t i, j;
        assert(target);
        for(i = {f.lo} + 1; i <= {f.hi}; ++i) {{
          for(j = i; j > {f.lo} && {self.element.compare(element_prev(f.target), element_j(f.target))} > 0; --j) {{
            {self.element.swap(element_prev(f.target), element_j(f.target))};
          }}
        }}
      """

    with self.method(None, ("sort", "range"), {"target": inout(self), "lo": index_type, "hi": index_type}, hidden=True, visibility="internal", constraint=sort_constraint, brief="Sort range using quicksort (internal)") as f:
      f.code = lambda f=f: f"""
        size_t i, j, mid;
        {pivot.definition};
        assert(target);
        while({f.lo} < {f.hi}) {{
          if({f.hi} - {f.lo} < 16) {{ /* small ranges are insertion sorted */
            {self.sort_insertion(f.target, f.lo, f.hi)};
            return;
          }}
          mid = {f.lo} + ({f.hi} - {f.lo})/2;
          /* median of three orders the lo, mid and hi elements protecting against the sorted inputs */
          if({self.element.compare(element_mid(f.target), element_lo(f.target))} < 0) {self.element.swap(element_mid(f.target), element_lo(f.target))};
          if({self.element.compare(element_hi(f.target), element_mid(f.target))} < 0) {{
            {self.element.swap(element_hi(f.target), element_mid(f.target))};
            if({self.element.compare(element_mid(f.target), element_lo(f.target))} < 0) {self.element.swap(element_mid(f.target), element_lo(f.target))};
          }}
          {self.element.copy(pivot, element_mid(f.target))};
          i = {f.lo};
          j = {f.hi};
          while(i <= j) {{
            while({self.element.compare(element_i(f.target), pivot)} < 0) ++i;
            while({self.element.compare(element_j(f.target), pivot)} > 0) --j;
            if(i >= j) break;
            {self.element.swap(element_i(f.target), element_j(f.target))};
            ++i;
            --j;
          }}
          {str(self.element.destroy(pivot)) + ";" if self.element.destructible else str()}
          /* recursing into the smaller part and iterating over the larger one bounds the recursion depth */
          if(j - {f.lo} < {f.hi} - i) {{
            {self.sort_range(f.target, f.lo, "j")};
            {f.lo} = i;
          }} else {{
            {self.sort_range(f.target, "i", f.hi)};
            {f.hi} = j;
          }}
        }}
      """

    with self.method(None, "sort", {"target": inout(self)}, constraint=sort_constraint, brief="Sort elements in ascending order",
      description="""
        Sorts the elements in ascending order in expected O(n log n) with a quicksort
        variant: ranges of less than 16 elements are insertion sorted, the pivot is the
        median of three which protects against the sorted inputs, and the recursion always
        descends into the smaller part to bound the depth. The sort is not stable and needs
        the element to be Orderable, Copyable and Swappable.

        @param[in,out] target the container to sort
      """) as f:
      f.code = lambda f=f: f"""
        assert(target);
        if({self._size_c(f.target)} > 1) {self.sort_range(f.target, 0, f"{self._size_c(f.target)}-1")};
      """

    # Reversal is a pure exchange loop so it requires nothing but the element swappability
    with self.method(None, "reverse", {"target": inout(self)}, constraint=lambda: self.element.swappable, brief="Reverse the order of elements",
      description="""
        Reverses the element order in place in O(n) by exchanging the mirrored element
        pairs. It needs nothing but the element swappability - no copies or destructions
        take place.

        @param[in,out] target the container to reverse
      """) as f:
      f.code = lambda f=f: f"""
        size_t i;
        assert(target);
        for(i = 0; i < {self._size_c(f.target)}/2; ++i) {{
          {self.element.swap(self._element_c(f.target, "i"), self._element_c(f.target, f"{self._size_c(f.target)}-1-i"))};
        }}
      """

    with self.method("int", "sorted", {"target": self}, constraint=lambda: self.element.orderable, brief="Check if elements are sorted in ascending order",
      description="""
        Walks the container once in O(n) returning non-zero when every element is not less
        than its predecessor. An empty or single element container is considered sorted.

        @param[in] target the container to check
        @return non-zero if the elements are sorted in ascending order
      """) as f:
      f.code = lambda f=f: f"""
        size_t index;
        assert(target);
        for(index = 1; index < {self._size_c(f.target)}; ++index) {{
          if({self.element.compare(self._element_c(f.target, "index"), self._element_c(f.target, "index-1"))} < 0) return 0;
        }}
        return 1;
      """

    with self.method(std.size_t, ("lower", "bound"), {"target": self, "element": self.element}, constraint=lambda: self.element.orderable, brief="Get the first position the element can be inserted at keeping the order",
      description="""
        Binary searches the sorted container in O(log n) returning the leftmost position the
        element can be inserted at keeping the ascending order. The container must be sorted
        in the ascending order beforehand.

        @param[in] target the sorted container to search
        @param[in] element the element to insert
        @return the position of the first element not less than the given one
      """) as f:
      f.code = lambda f=f: f"""
        size_t low, high, mid;
        assert(target);
        low = 0;
        high = {self._size_c(f.target)};
        while(low < high) {{
          mid = low + (high - low)/2;
          if({self.element.compare(self._element_c(f.target, "mid"), f.element)} < 0) low = mid + 1;
          else high = mid;
        }}
        return low;
      """

    with self.method(std.size_t, ("upper", "bound"), {"target": self, "element": self.element}, constraint=lambda: self.element.orderable, brief="Get the last position the element can be inserted at keeping the order",
      description="""
        Binary searches the sorted container in O(log n) returning the rightmost position the
        element can be inserted at keeping the ascending order. The container must be sorted
        in the ascending order beforehand.

        @param[in] target the sorted container to search
        @param[in] element the element to compare with
        @return the position of the first element greater than the given one
      """) as f:
      f.code = lambda f=f: f"""
        size_t low, high, mid;
        assert(target);
        low = 0;
        high = {self._size_c(f.target)};
        while(low < high) {{
          mid = low + (high - low)/2;
          if({self.element.compare(self._element_c(f.target, "mid"), f.element)} <= 0) low = mid + 1;
          else high = mid;
        }}
        return low;
      """

    with self.method("int", ("binary", "search"), {"target": self, "element": self.element}, constraint=lambda: self.element.orderable, brief="Check if the element is present in the sorted container",
      description="""
        Binary searches the sorted container in O(log n) for the element. The container must be
        sorted in the ascending order beforehand.

        @param[in] target the sorted container to search
        @param[in] element the element to look for
        @return non-zero if the element is present in the container
      """) as f:
      f.code = lambda f=f: f"""
        size_t low;
        assert(target);
        low = {self.lower_bound(f.target, f.element)};
        return low < {self._size_c(f.target)} && !{self.element.compare(self._element_c(f.target, "low"), f.element)};
      """
