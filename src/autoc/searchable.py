import autoc.std as std
from autoc.core import _type


# Mixin class providing binary search algorithms for direct-access containers.
class Searchable:

  def __init__(self, *args, search_operations=True, search_optional_group=None, **kws):
    self.search_operations = bool(search_operations)
    self.search_optional_group = search_optional_group
    super().__init__(*args, **kws)

  @property
  def index_type(self):
    return self.index

  # Protocol handlers
  
  # def _element(self, target, index):
  #   pass

  # def _target_size(self, target):
  #   pass

  def __setup__(self):
    super().__setup__()

    self.dependencies.add(self.index)
    search_constraint = lambda: self.search_operations and self.element.orderable

    with self.method(self.index, ("lower", "bound"), {"target": self, "element": self.element}, constraint=search_constraint, optional_group=self.search_optional_group, brief="Get the first position the element can be inserted at keeping the order",
      description="""
        Binary searches the sorted container in O(log n) returning the leftmost position the
        element can be inserted at keeping the ascending order. The container must be sorted
        in the ascending order beforehand.

        @param[in] target the sorted container to search
        @param[in] element the element to insert
        @return the position of the first element not less than the given one
      """) as f:
      f.code = lambda f=f: f"""
        {self.index} low, high, mid;
        assert(target);
        low = 0;
        high = {self._target_size(f.target)};
        while(low < high) {{
          mid = low + (high - low)/2;
          if({self.element.compare(self._element(f.target, "mid"), f.element)} < 0) low = mid + 1;
          else high = mid;
        }}
        return low;
      """

    with self.method(self.index, ("upper", "bound"), {"target": self, "element": self.element}, constraint=search_constraint, optional_group=self.search_optional_group, brief="Get the last position the element can be inserted at keeping the order",
      description="""
        Binary searches the sorted container in O(log n) returning the rightmost position the
        element can be inserted at keeping the ascending order. The container must be sorted
        in the ascending order beforehand.

        @param[in] target the sorted container to search
        @param[in] element the element to compare with
        @return the position of the first element greater than the given one
      """) as f:
      f.code = lambda f=f: f"""
        {self.index} low, high, mid;
        assert(target);
        low = 0;
        high = {self._target_size(f.target)};
        while(low < high) {{
          mid = low + (high - low)/2;
          if({self.element.compare(self._element(f.target, "mid"), f.element)} <= 0) low = mid + 1;
          else high = mid;
        }}
        return low;
      """

    with self.method("int", ("binary", "search"), {"target": self, "element": self.element}, constraint=search_constraint, optional_group=self.search_optional_group, references=(self.lower_bound,), brief="Check if the element is present in the sorted container",
      description="""
        Binary searches the sorted container in O(log n) for the element. The container must be
        sorted in the ascending order beforehand.

        @param[in] target the sorted container to search
        @param[in] element the element to look for
        @return non-zero if the element is present in the container
      """) as f:
      f.code = lambda f=f: f"""
        {self.index} low;
        assert(target);
        low = {self.lower_bound(f.target, f.element)};
        return low < {self._target_size(f.target)} && !{self.element.compare(self._element(f.target, "low"), f.element)};
      """
