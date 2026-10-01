import autoc.std as std
from autoc.core import inout
from autoc.bisectable import Bisectable


# Mixin class providing in-place sorting, reversal, and binary search algorithms
# for direct-access sequence containers.
class Sortable(Bisectable):

  def __init__(self, *args, sorting_operations=True, **kws):
    self.sorting_operations = bool(sorting_operations)
    super().__init__(*args, bisection_operations=sorting_operations, bisection_optional_group="sorting_operations", **kws)

  def __setup__(self):
    super().__setup__()

    sort_constraint = lambda: self.sorting_operations and self.element.orderable and self.element.copyable and self.element.swappable
    reverse_constraint = lambda: self.sorting_operations and self.element.swappable
    search_constraint = lambda: self.sorting_operations and self.element.orderable

    element_i = lambda target="target": self._element(target, "i")
    element_j = lambda target="target": self._element(target, "j")
    element_lo = lambda target="target": self._element(target, "lo")
    element_mid = lambda target="target": self._element(target, "mid")
    element_hi = lambda target="target": self._element(target, "hi")
    element_prev = lambda target="target": self._element(target, "j-1")
    pivot = self.element.variable("pivot")

    with self.method(None, ("sort", "insertion"), {"target": inout(self), "lo": std.size_t, "hi": std.size_t}, hidden=True, visibility="internal", constraint=sort_constraint, brief="Sort range using insertion sort (internal)") as f:
      f.code = lambda f=f: f"""
        size_t i, j;
        assert(target);
        for(i = {f.lo} + 1; i <= {f.hi}; ++i) {{
          for(j = i; j > {f.lo} && {self.element.compare(element_prev(f.target), element_j(f.target))} > 0; --j) {{
            {self.element.swap(element_prev(f.target), element_j(f.target))};
          }}
        }}
      """

    with self.method(None, ("sort", "range"), {"target": inout(self), "lo": std.size_t, "hi": std.size_t}, hidden=True, visibility="internal", constraint=sort_constraint, references=(self.sort_insertion,), brief="Sort range using quicksort (internal)") as f:
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

    with self.method(None, "sort", {"target": inout(self)}, constraint=sort_constraint, optional_group="sorting_operations", references=(self.sort_range,), brief="Sort elements in ascending order",
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
        if({self._target_size(f.target)} > 1) {self.sort_range(f.target, 0, f"{self._target_size(f.target)}-1")};
      """

    # Reversal is a pure exchange loop so it requires nothing but the element swappability
    with self.method(None, "reverse", {"target": inout(self)}, constraint=reverse_constraint, optional_group="sorting_operations", brief="Reverse the order of elements",
      description="""
        Reverses the element order in place in O(n) by exchanging the mirrored element
        pairs. It needs nothing but the element swappability - no copies or destructions
        take place.

        @param[in,out] target the container to reverse
      """) as f:
      f.code = lambda f=f: f"""
        size_t i;
        assert(target);
        for(i = 0; i < {self._target_size(f.target)}/2; ++i) {{
          {self.element.swap(self._element(f.target, "i"), self._element(f.target, f"{self._target_size(f.target)}-1-i"))};
        }}
      """

    with self.method("int", "sorted", {"target": self}, constraint=search_constraint, optional_group="sorting_operations", brief="Check if elements are sorted in ascending order",
      description="""
        Walks the container once in O(n) returning non-zero when every element is not less
        than its predecessor. An empty or single element container is considered sorted.

        @param[in] target the container to check
        @return non-zero if the elements are sorted in ascending order
      """) as f:
      f.code = lambda f=f: f"""
        size_t index;
        assert(target);
        for(index = 1; index < {self._target_size(f.target)}; ++index) {{
          if({self.element.compare(self._element(f.target, "index"), self._element(f.target, "index-1"))} < 0) return 0;
        }}
        return 1;
      """
