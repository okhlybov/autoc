import autoc.std as std
from autoc.core import _StructRenderer, Callable, inout
from autoc.container import _Range
from autoc.core import TraitError
from autoc.mapping import Mapping
from autoc.multiset import Multiset
from autoc.range import Forward


# Multiset container tracking element frequencies
class Counter(_StructRenderer, Multiset):

  brief = "Multiset container tracking element frequencies"

  def __init__(self, name, element, backend, *args, algebraic_operations=True, dependencies=(), **kws):
    # FIXME selectors
    if backend is None or not issubclass(backend, Mapping):
      raise TraitError(f"Counter '{name}' requires an explicit mapping backend class (e.g. autoc.flat_map.Map, autoc.chained_hash_map.Map)")
    self.backend = backend
    super().__init__(name, element, *args, algebraic_operations=algebraic_operations, dependencies=(*dependencies, std.string_h), **kws)
    self._map = backend(
      self._decorate_component("map", abbreviate=True),
      std.size_t,
      self.element,
      visibility="internal",
    )
    self.dependencies.add(self._map)
    self.range = Range(self)

  @property
  def constructible(self):
    return True

  @property
  def default_constructible(self):
    return True

  @property
  def destructible(self):
    return True

  @property
  def copyable(self):
    return True

  @property
  def moveable(self):
    return True

  @property
  def swappable(self):
    return True

  @property
  def comparable(self):
    return True

  @property
  def orderable(self):
    return self._map.orderable

  @property
  def hashable(self):
    return True

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._map.name} map; /**< @private */
        size_t total_size; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Multiset / frequency counter tracking occurrences of unique @ref {self.element} values.
      Backed by an internal map mapping elements to their multiplicity counters.

      Tracks both total multiplicity (`size`) and unique element count (`distinct_size`) in O(1).
      Supports frequency queries, incremental add/remove, and multiset set algebra.
    """

    _target = self._map.variable("target->map")
    _source = self._map.variable("source->map")
    _left = self._map.variable("left->map")
    _right = self._map.variable("right->map")

    with self.create as f:
      f.code = f"""
        assert(target);
        {self._map.create(_target)};
        target->total_size = 0;
      """

    with self.destroy as f:
      f.code = f"""
        assert(target);
        {self._map.destroy(_target)};
      """

    with self.copy as f:
      f.code = f"""
        assert(target);
        assert(source);
        {self._map.copy(_target, _source)};
        target->total_size = source->total_size;
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        {self._map.move(_target, _source)};
        target->total_size = source->total_size;
        source->total_size = 0;
      """

    with self.swap as f:
      f.code = f"""
        size_t tmp_size;
        assert(left);
        assert(right);
        {self._map.swap(_left, _right)};
        tmp_size = left->total_size;
        left->total_size = right->total_size;
        right->total_size = tmp_size;
      """

    with self.equal as f:
      f.code = f"""
        assert(left);
        assert(right);
        if(left->total_size != right->total_size) return 0;
        return {self._map.equal(_left, _right)};
      """

    if self.orderable:
      with self.compare as f:
        f.code = f"""
          assert(left);
          assert(right);
          return {self._map.compare(_left, _right)};
        """

    with self.hash as f:
      f.code = f"""
        assert(target);
        return {self._map.hash(_target)};
      """

    with self.empty as f:
      f.code = f"""
        assert(target);
        return target->total_size == 0;
      """

    with self.size as f:
      f.code = f"""
        assert(target);
        return target->total_size;
      """

    with self.method(std.size_t, ("total", "size"), {"target": self}, brief="Get total number of elements including duplicates",
      description="""
        Returns the sum of multiplicities across all elements in the counter in O(1).

        @param[in] target the counter to measure
        @return the total element count
      """) as f:
      f.code = f"""
        assert(target);
        return target->total_size;
      """

    with self.method(std.size_t, ("distinct", "size"), {"target": self}, brief="Get number of unique elements",
      description="""
        Returns the number of distinct elements present in the counter in O(1).

        @param[in] target the counter to measure
        @return the count of distinct elements
      """) as f:
      f.code = f"""
        assert(target);
        return {self._map.size(_target)};
      """

    with self.method(None, "clear", {"target": inout(self)}, brief="Clear all elements from counter",
      description="""
        Removes all elements from the counter, resetting total and distinct sizes to zero.

        @param[in,out] target the counter to clear
      """) as f:
      f.code = f"""
        assert(target);
        {self._map.destroy(_target)};
        {self._map.create(_target)};
        target->total_size = 0;
      """

    with self.count as f:
      f.code = f"""
        const size_t* v;
        assert(target);
        v = (const size_t*){self._map.view(_target, f.element)};
        return v ? *v : 0;
      """

    with self.contains as f:
      f.code = f"""
        assert(target);
        return {self.count(f.target, f.element)} > 0;
      """

    with self.method(None, "add", {"target": inout(self), "element": self.element, "count": std.size_t}, brief="Add element with multiplicity",
      description="""
        Increments the multiplicity of the element by `count`.
        If the element is not already present, it is inserted with multiplicity `count`.

        @param[in,out] target the counter to modify
        @param[in] element the element to add
        @param[in] count the multiplicity to add
      """) as f:
      f.code = f"""
        const size_t* v;
        assert(target);
        if(count == 0) return;
        v = (const size_t*){self._map.view(_target, f.element)};
        if(v) {{
          {self._map.set(_target, f.element, "*v + count")};
        }} else {{
          {self._map.set(_target, f.element, "count")};
        }}
        target->total_size += count;
      """

    with self.method(std.size_t, "subtract", {"target": inout(self), "element": self.element, "count": std.size_t}, brief="Subtract element multiplicity",
      description="""
        Decrements the multiplicity of the element by at most `count`.
        If the remaining multiplicity reaches zero, the element is removed from the counter.

        @param[in,out] target the counter to modify
        @param[in] element the element to remove
        @param[in] count the maximum multiplicity to remove
        @return the number of occurrences actually removed
      """) as f:
      f.code = f"""
        const size_t* v;
        size_t old_count, removed;
        assert(target);
        if(count == 0) return 0;
        v = (const size_t*){self._map.view(_target, f.element)};
        if(!v) return 0;
        old_count = *v;
        if(old_count <= count) {{
          removed = old_count;
          {self._map.remove(_target, f.element)};
        }} else {{
          removed = count;
          {self._map.set(_target, f.element, "old_count - count")};
        }}
        target->total_size -= removed;
        return removed;
      """

    with self.method(std.size_t, ("remove", "count"), {"target": inout(self), "element": self.element, "count": std.size_t}, brief="Remove element multiplicity",
      description="""
        Decrements the multiplicity of the element by at most `count`.
        Alias for `subtract`.

        @param[in,out] target the counter to modify
        @param[in] element the element to remove
        @param[in] count the maximum multiplicity to remove
        @return the number of occurrences actually removed
      """) as f:
      f.inline_code = lambda f=f: f"""
        return {self.subtract(f.target, f.element, f.count)};
      """

    with self.put as f:
      f.code = f"""
        assert(target);
        {self.add(f.target, f.element, 1)};
        return 1;
      """

    with self.emplace as f:
      def _emplace_code(f=f):
        create_args = [getattr(f, name) for name in self.element.constructor_parameters]
        _temp = self.element.variable("temp")
        _destroy_temp = f"{self.element.destroy(_temp)};" if self.element.destructible else ""
        return f"""
          {_temp.definition};
          assert(target);
          {self.element.create(_temp, *create_args)};
          {self.add(f.target, _temp, 1)};
          {_destroy_temp}
          return 1;
        """
      f.code = _emplace_code

    with self.remove as f:
      f.code = f"""
        const size_t* v;
        size_t old_count;
        assert(target);
        v = (const size_t*){self._map.view(_target, f.element)};
        if(!v) return 0;
        old_count = *v;
        if(old_count <= 1) {{
          {self._map.remove(_target, f.element)};
        }} else {{
          {self._map.set(_target, f.element, "old_count - 1")};
        }}
        target->total_size -= 1;
        return 1;
      """

    with self.wipe as f:
      f.code = f"""
        const size_t* v;
        size_t old_count;
        assert(target);
        v = (const size_t*){self._map.view(_target, f.element)};
        if(!v) return 0;
        old_count = *v;
        {self._map.remove(_target, f.element)};
        target->total_size -= old_count;
        return old_count;
      """

    with self.method(std.size_t, ("remove", "all"), {"target": inout(self), "element": self.element}, brief="Remove all occurrences of element",
      description="""
        Completely removes the element from the counter regardless of its multiplicity.
        Alias for `wipe`.

        @param[in,out] target the counter to modify
        @param[in] element the element to remove completely
        @return the multiplicity removed
      """) as f:
      f.inline_code = lambda f=f: f"""
        return {self.wipe(f.target, f.element)};
      """

    with self.equal_range as f:
      result = f.result.variable("result")
      single = self.element.variable("result.single_element")
      f.code = lambda f=f: f"""
        {result.definition};
        size_t cnt;
        assert(target);
        cnt = {self.count(f.target, f.element)};
        result.counter = target;
        result.is_single = 1;
        result.single_count = cnt;
        if(cnt > 0) {{
          {self.element.copy(single, f.element)};
        }}
        return {result};
      """

    # --- Algebraic multiset operations ---
    r = self.range.variable("r")
    elem = self.element.variable("elem")

    with self.union as f:
      f.code = lambda f=f: f"""
        size_t added = 0;
        {r.definition};
        assert(target);
        assert(other);
        if(target == other) return 0;
        for({r} = {self.range.new(f.other)}; !{self.range.empty(r)}; {self.range.move_front(r)}) {{
          {elem.definition} = {self.range.front(r)};
          size_t o_cnt = {self.range.count(r)};
          size_t t_cnt = {self.count(f.target, elem)};
          if(o_cnt > t_cnt) {{
            {self.add(f.target, elem, "o_cnt - t_cnt")};
            added += o_cnt - t_cnt;
          }}
        }}
        return added;
      """

    with self.difference as f:
      f.code = lambda f=f: f"""
        size_t removed = 0;
        {r.definition};
        assert(target);
        assert(other);
        if(target == other) {{
          removed = target->total_size;
          {self.clear(f.target)};
          return removed;
        }}
        for({r} = {self.range.new(f.other)}; !{self.range.empty(r)}; {self.range.move_front(r)}) {{
          {elem.definition} = {self.range.front(r)};
          size_t o_cnt = {self.range.count(r)};
          removed += {self.subtract(f.target, elem, "o_cnt")};
        }}
        return removed;
      """

    with self.intersection as f:
      temp = self.variable("temp")
      f.code = lambda f=f: f"""
        size_t removed = 0;
        {self.name} {temp};
        {r.definition};
        assert(target);
        assert(other);
        if(target == other) return 0;
        {self.create(temp)};
        {self.copy(temp, f.target)};
        for({r} = {self.range.new(temp)}; !{self.range.empty(r)}; {self.range.move_front(r)}) {{
          {elem.definition} = {self.range.front(r)};
          size_t t_cnt = {self.range.count(r)};
          size_t o_cnt = {self.count(f.other, elem)};
          if(o_cnt == 0) {{
            removed += {self.wipe(f.target, elem)};
          }} else if(t_cnt > o_cnt) {{
            removed += {self.subtract(f.target, elem, "t_cnt - o_cnt")};
          }}
        }}
        {self.destroy(temp)};
        return removed;
      """

    with self.symmetric_difference as f:
      temp = self.variable("temp")
      f.code = lambda f=f: f"""
        size_t changed = 0;
        {self.name} {temp};
        {r.definition};
        assert(target);
        assert(other);
        if(target == other) {{
          changed = target->total_size;
          {self.clear(f.target)};
          return changed;
        }}
        {self.create(temp)};
        for({r} = {self.range.new(f.other)}; !{self.range.empty(r)}; {self.range.move_front(r)}) {{
          {elem.definition} = {self.range.front(r)};
          size_t o_cnt = {self.range.count(r)};
          size_t t_cnt = {self.count(f.target, elem)};
          if(o_cnt > t_cnt) {{
            {self.add(temp, elem, "o_cnt - t_cnt")};
          }}
        }}
        for({r} = {self.range.new(f.target)}; !{self.range.empty(r)}; {self.range.move_front(r)}) {{
          {elem.definition} = {self.range.front(r)};
          size_t t_cnt = {self.range.count(r)};
          size_t o_cnt = {self.count(f.other, elem)};
          if(o_cnt > 0) {{
            size_t rem = t_cnt > o_cnt ? o_cnt : t_cnt;
            {self.subtract(f.target, elem, "rem")};
            changed += rem;
          }}
        }}
        for({r} = {self.range.new(temp)}; !{self.range.empty(r)}; {self.range.move_front(r)}) {{
          {elem.definition} = {self.range.front(r)};
          size_t cnt = {self.range.count(r)};
          {self.add(f.target, elem, "cnt")};
          changed += cnt;
        }}
        {self.destroy(temp)};
        return changed;
      """

    with self.is_subset as f:
      f.code = lambda f=f: f"""
        {r.definition};
        assert(target);
        assert(other);
        if(target == other) return 1;
        if(target->total_size > other->total_size) return 0;
        for({r} = {self.range.new(f.target)}; !{self.range.empty(r)}; {self.range.move_front(r)}) {{
          {elem.definition} = {self.range.front(r)};
          size_t t_cnt = {self.range.count(r)};
          size_t o_cnt = {self.count(f.other, elem)};
          if(t_cnt > o_cnt) return 0;
        }}
        return 1;
      """

    with self.is_superset as f:
      f.code = lambda f=f: f"""
        assert(target);
        assert(other);
        return {self.is_subset(f.other, f.target)};
      """

    with self.method(None, ("assign", "union"), {"target": inout(self), "other": self},
      constraint=lambda: self.algebraic_operations,
      optional_group="algebraic_operations",
      brief="In-place multiset union (maximum multiplicities)",
      description="""
        Updates target so that for each element, count(target) = max(count(target), count(other)).
        Alias for `union`.

        @param[in,out] target the destination counter
        @param[in] other the counter to unite with
      """) as f:
      f.inline_code = lambda f=f: f"""
        ((void){self.union(f.target, f.other)});
      """

    with self.method(None, ("assign", "intersection"), {"target": inout(self), "other": self},
      constraint=lambda: self.algebraic_operations,
      optional_group="algebraic_operations",
      brief="In-place multiset intersection (minimum multiplicities)",
      description="""
        Updates target so that for each element, count(target) = min(count(target), count(other)).
        Alias for `intersection`.

        @param[in,out] target the destination counter
        @param[in] other the counter to intersect with
      """) as f:
      f.inline_code = lambda f=f: f"""
        ((void){self.intersection(f.target, f.other)});
      """

    with self.method(None, ("assign", "difference"), {"target": inout(self), "other": self},
      constraint=lambda: self.algebraic_operations,
      optional_group="algebraic_operations",
      brief="In-place multiset difference",
      description="""
        Subtracts the multiplicities of elements in `other` from `target`.
        Alias for `difference`.

        @param[in,out] target the counter to subtract from
        @param[in] other the counter whose multiplicities are subtracted
      """) as f:
      f.inline_code = lambda f=f: f"""
        ((void){self.difference(f.target, f.other)});
      """


# Range iterator over unique elements and their counts
class Range(_Range, Forward):

  brief = "Forward range over unique elements and their counts in Counter"

  def __init__(self, iterable, *args, **kws):
    super().__init__(iterable, *args, **kws)
    self._map_range = iterable._map.range
    self.element = iterable.element
    self.dependencies.add(self._map_range)

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._map_range.name} range; /**< @private */
        const {self.iterable.name}* counter; /**< @private */
        {self.element} single_element; /**< @private */
        size_t single_count; /**< @private */
        int is_single; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    order_doc = "in ascending element order" if self.iterable.orderable else "in unspecified map order"

    self.description = f"""
      Iterates over distinct elements held in @ref {self.iterable.name} {order_doc}.
      Yields the element value/view and its multiplicity count at each step.
    """

    _range = self._map_range.variable("target->range")

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create range over counter",
      description=f"""
        Creates a range over the counter, yielding distinct elements and their counts {order_doc}.

        @param[in] iterable the counter to span
        @return the range covering the counter
      """) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(iterable);
        result.range = {self._map_range.new(f"&{f.iterable}->map")};
        result.counter = iterable;
        result.single_count = 0;
        result.is_single = 0;
        return {result};
      """

    with self.empty as f:
      f.code = f"""
        assert(target);
        if(target->is_single) return target->single_count == 0;
        return {self._map_range.empty(_range)};
      """

    with self.move_front as f:
      f.code = f"""
        assert(target);
        if(target->is_single) {{
          target->single_count = 0;
          return;
        }}
        {self._map_range.move_front(_range)};
      """

    with self.front_view as f:
      f.code = f"""
        assert(target);
        if(target->is_single) return &target->single_element;
        return {self._map_range.index_front_view(_range)};
      """

    with self.front as f:
      f.code = f"""
        assert(target);
        if(target->is_single) return target->single_element;
        return {self._map_range.index_front(_range)};
      """

    with self.method(std.size_t, "count", {"target": self}, brief="Get multiplicity of current element",
      description="""
        Returns the multiplicity count of the element at the current range position.

        @param[in] target the range to read
        @return the multiplicity count
      """) as f:
      f.code = f"""
        assert(target);
        if(target->is_single) return target->single_count;
        return *{self._map_range.front_view(_range)};
      """
