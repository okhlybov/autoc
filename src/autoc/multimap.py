import autoc.std as std
from autoc.core import inout, Callable, _type, _StructRenderer, Indirection
from autoc.collection import Collection, _Range
from autoc.range import Forward


# Common Forward range for multimaps
class Range(_Range, Forward):

  brief = "Forward range over the multimap indices and elements"

  def __init__(self, iterable, *args, dependencies=(), **kws):
    super().__init__(iterable, *args, dependencies=(*dependencies, std.assert_h), **kws)
    self._range = iterable._set.range
    self._entry = iterable._set.element
    self.index = iterable.index
    self.dependencies.update((self._entry, self._range))

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._range.name} range; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    _target_range = self._range.variable("target->range")
    is_ordered = self.iterable.orderable
    order_doc = "in ascending index order" if is_ordered else "in unspecified order"
    front_doc = "the lowest index" if is_ordered else "the entry found first in the layout"

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create the range spanning the whole multimap",
      description=f"""
        Creates the range over the multimap which starts at the first entry and
        proceeds {order_doc}. The range must not outlive the multimap and the multimap
        must not be modified while the range is traversed.

        @param[in] iterable the multimap to span
        @return the range covering the whole multimap {order_doc}
      """) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(iterable);
        result.range = {self._range.new(f"&{f.iterable}->set")};
        return {result};
      """

    with self.empty as f:
      f.code = f"""
        assert(target);
        return {self._range.empty(_target_range)};
      """

    with self.method(self.index.view_type, ("index", "front", "view"), {"target": self}, brief="Get view of front index",
      description=f"""
        Returns a pointer to the index of {front_doc}.
        The view is valid while that entry is held by the multimap.

        @param[in] target the non-empty range to inspect
        @return a constant view of the front index
      """) as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self._entry.index_view(self._range.front_view(_target_range)).bind(self.index.view_type)};
      """

    with self.front as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, self._entry.element_view(self._range.front_view(_target_range)))};
        return {result};
      """

    with self.front_view as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self._entry.element_view(self._range.front_view(_target_range)).bind(self.element.view_type)};
      """

    with self.method(self.index, ("index", "front"), {"target": self}, constraint=lambda: self.index.copyable, brief="Get front index",
      description=f"""
        Returns a copy of the index of {front_doc}.

        @param[in] target the non-empty range to inspect
        @return a copy of the front index
      """) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.index.copy(result, self._entry.index_view(self._range.front_view(_target_range)))};
        return {result};
      """

    with self.move_front as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        {self._range.move_front(_target_range)};
      """

    if hasattr(self._range, "size"):
      with self.method(std.size_t, "size", {"target": self}, brief="Get number of remaining elements in range",
        description="""
          Returns the number of elements remaining in the range in O(1).

          @param[in] target the range to measure
          @return number of elements
        """) as f:
        f.code = f"""
          assert(target);
          return {self._range.size(_target_range)};
        """


# Abstract base class for associative multimaps backed by an underlying multiset
class _Multimap(_StructRenderer, Collection):

  brief = "Abstract associative multimap container mapping keys to multiple values backed by an underlying multiset"

  def __init__(self, name, element, index, *args, dependencies=(), **kws):
    self.index = _type(index)
    super().__init__(name, element, *args, dependencies=(*dependencies, std.assert_h, std.stdlib_h), **kws)
    self.dependencies.add(self.index)

  def _setup_range(self):
    self.range = Range(self)

  @property
  def copyable(self):
    return self.element.copyable and self.index.copyable

  @property
  def hashable(self):
    return self.element.hashable and self.index.hashable

  @property
  def comparable(self):
    return self.element.comparable and self.index.comparable

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._set.variable("set").definition}; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    valid_index = lambda: self.index.comparable or self.index.orderable

    _target = self._set.variable("target->set")
    _source = self._set.variable("source->set")
    _left = self._set.variable("left->set")
    _right = self._set.variable("right->set")

    with self.create as f:
      f.code = f"""
        assert(target);
        {self._set.create(_target)};
      """

    with self.destroy as f:
      f.code = f"""
        assert(target);
        {self._set.destroy(_target)};
      """

    with self.copy as f:
      f.code = f"""
        assert(target);
        assert(source);
        {self._set.copy(_target, _source)};
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        {self._set.move(_target, _source)};
      """

    with self.equal as f:
      f.code = f"""
        assert(left);
        assert(right);
        return {self._set.equal(_left, _right)};
      """

    with self.hash as f:
      f.code = f"""
        assert(target);
        return {self._set.hash(_target)};
      """

    with self.empty as f:
      f.code = f"""
        assert(target);
        return {self._set.empty(_target)};
      """

    with self.size as f:
      f.code = f"""
        assert(target);
        return {self._set.size(_target)};
      """

    set = self._set
    entry = set.element
    _entry = entry.variable("entry")

    with self.contains as f:
      r = set.range.variable("r")
      f.code = f"""
        {r.definition};
        assert(target);
        for({r} = {set.range.new(_target)}; !{set.range.empty(r)}; {set.range.move_front(r)}) {{
          if({self.element.equal(entry.element_view(set.range.front_view(r)), f.element)}) return 1;
        }}
        return 0;
      """

    with self.method(self.element.view_type, "view", {"target": self, "index": self.index}, constraint=valid_index, brief="Get view of first element with key",
      description="""
        Returns a constant view of the first element associated with the index, or NULL if absent.

        @param[in] target the multimap to query
        @param[in] index the key to look for
        @return constant pointer to element, or NULL if not found
      """) as f:
      found = Indirection(entry, constant=True).variable("found")
      f.code = f"""
        {_entry.definition};
        {found.definition};
        assert(target);
        {entry.emplace_index(_entry, f.index)};
        {found} = {set.find_view(_target, _entry)};
        {entry.destroy_index(_entry)};
        if({found}) {{
          return {entry.element_view(found)};
        }}
        return ({self.element.view_type})NULL;
      """

    with self.method("int", "indexed", {"target": self, "index": self.index}, constraint=valid_index, brief="Check if multimap contains key",
      description="""
        Checks whether the multimap contains at least one entry with the specified index.

        @param[in] target the multimap to query
        @param[in] index the key to look for
        @return non-zero if the key is present, zero otherwise
      """) as f:
      f.code = f"""
        assert(target);
        return {self.view(f.target, f.index)} != NULL;
      """

    with self.method(self.element, "get", {"target": self, "index": self.index}, constraint=lambda: valid_index() and self.element.copyable, brief="Get copy of first element with key",
      description="""
        Returns an owned copy of the first element associated with the index. Aborts if the key is absent.

        @param[in] target the multimap to query
        @param[in] index the key to look for
        @return copy of the element
      """) as f:
      _element_p = entry.element_p.variable("element_p")
      result = f.result.variable("result")
      f.code = f"""
        {_element_p.definition};
        {result.definition};
        assert(target);
        {_element_p} = ({_element_p.type}){self.view(f.target, f.index)};
        if(!{_element_p}) abort();
        {self.element.copy(result, _element_p)};
        return {result};
      """

    with self.method("int", "put", {"target": inout(self), "index": self.index, "element": self.element},
      constraint=lambda: valid_index() and self.element.copyable, brief="Insert key-value entry into multimap",
      description="""
        Inserts a new key-value entry into the multimap, preserving duplicate keys.

        @param[in,out] target the multimap to insert into
        @param[in] index the key of the new entry
        @param[in] element the value of the new entry
        @return always non-zero
      """) as f:
      f.code = f"""
        {_entry.definition};
        assert(target);
        {entry.emplace_index(_entry, f.index)};
        {entry.emplace_element(_entry, f.element)};
        {set.put(_target, _entry)};
        {entry.destroy_element(_entry)};
        {entry.destroy_index(_entry)};
        return 1;
      """

    with self.method("int", "remove", {"target": inout(self), "index": self.index}, constraint=valid_index, brief="Remove one entry with specified key",
      description="""
        Removes one occurrence of an entry with the specified index, if present.

        @param[in,out] target the multimap to modify
        @param[in] index the key to remove
        @return non-zero if an entry was removed, zero if absent
      """) as f:
      f.code = f"""
        {_entry.definition};
        int removed;
        assert(target);
        {entry.emplace_index(_entry, f.index)};
        removed = {set.remove(_target, _entry)};
        {entry.destroy_index(_entry)};
        return removed;
      """

    with self.method(std.size_t, "wipe", {"target": inout(self), "index": self.index}, constraint=valid_index, brief="Remove all entries with specified key",
      description="""
        Removes all entries associated with the specified index from the multimap.

        @param[in,out] target the multimap to modify
        @param[in] index the key to remove
        @return number of entries removed
      """) as f:
      f.code = f"""
        {_entry.definition};
        size_t wiped;
        assert(target);
        {entry.emplace_index(_entry, f.index)};
        wiped = {set.wipe(_target, _entry)};
        {entry.destroy_index(_entry)};
        return wiped;
      """

    with self.method(std.size_t, "count", {"target": self, "index": self.index}, constraint=valid_index, brief="Count entries with key",
      description="""
        Returns the number of entries associated with the specified index.

        @param[in] target the multimap to query
        @param[in] index the key to count
        @return number of matching entries
      """) as f:
      f.code = f"""
        {_entry.definition};
        size_t cnt;
        assert(target);
        {entry.emplace_index(_entry, f.index)};
        cnt = {set.count(_target, _entry)};
        {entry.destroy_index(_entry)};
        return cnt;
      """

    with self.method(Callable.Parameter(self.range), ("equal", "range"), {"target": self, "index": self.index}, constraint=valid_index, brief="Get range covering all entries with key",
      description="""
        Returns a range spanning all entries with the specified index.
        If the key is absent, an empty range is returned.

        @param[in] target the multimap to search
        @param[in] index the key to search for
        @return range covering all matching entries
      """) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        {_entry.definition};
        assert(target);
        {entry.emplace_index(_entry, f.index)};
        result.range = {set.equal_range(_target, _entry)};
        {entry.destroy_index(_entry)};
        return {result};
      """