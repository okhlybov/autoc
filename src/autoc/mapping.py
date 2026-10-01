import autoc.std as std
from autoc.record import Record
from autoc.core import inout, Callable, _StructRenderer, Macro
from autoc.collection import _Range
from autoc.range import Forward
from autoc.indexed import Indexed


# Common entry implementation for maps backed by an underlying set
class _Entry(Record):
  
  def __init__(self, name, element, index, visibility, *args, **kws):
    super().__init__(name, {"element": element, "index": index}, *args, visibility=visibility, **kws)
    self.index = self.fields["index"]
    self.element = self.fields["element"]
    self.element_p = self.element.view_type
    self.index_p = self.index.view_type

  def __setup__(self):
    super().__setup__()

    _index = self.index.variable("target->index")
    _element = self.element.variable("target->element")

    with self.method(Callable.Parameter(self.element_p), ("element", "view"), {"target": self}, hidden=True, visibility="internal", brief="Get view of element (internal)") as f:
      f.code = f"""
        assert(target);
        return {self.element.variable("target->element").bind(f.result)};
      """

    with self.method(Callable.Parameter(self.index_p), ("index", "view"), {"target": self}, hidden=True, visibility="internal", brief="Get view of index (internal)") as f:
      f.code = f"""
        assert(target);
        return {self.index.variable("target->index").bind(f.result)};
      """

    with self.method(None, ("emplace", "index"), {"target": inout(self), "index": self.index}, hidden=True, visibility="internal", constraint=lambda: self.index.copyable, brief="Emplace index (internal)") as f:
      f.code = f"""
        assert(target);
        {self.index.copy(_index, f.index)};
      """

    with self.method(None, ("destroy", "index"), {"target": inout(self)}, hidden=True, visibility="internal", brief="Destroy index (internal)") as f:
      if self.index.destructible:
        f.code = f"""
          assert(target);
          {self.index.destroy(_index)};
        """
      else:
        f.code = f"""
          assert(target);
        """
      
    with self.method(None, ("emplace", "element"), {"target": inout(self), "element": self.element}, hidden=True, visibility="internal", constraint=lambda: self.element.copyable, brief="Emplace element (internal)") as f:
      f.code = f"""
        assert(target);
        {self.element.copy(_element, f.element)};
      """

    with self.method(None, ("destroy", "element"), {"target": inout(self)}, hidden=True, visibility="internal", brief="Destroy element (internal)") as f:
      if self.element.destructible:
        f.code = f"""
          assert(target);
          {self.element.destroy(_element)};
        """
      else:
        f.code = f"""
          assert(target);
        """

    with self.method(None, ("replace", "element"), {"target": inout(self), "element": self.element}, hidden=True, visibility="internal", constraint=lambda: self.element.copyable and self.element.comparable, brief="Replace element in-place (internal)") as f:
      f.code = f"""
        assert(target);
        {self.destroy_element(f.target)};
        {self.element.copy(_element, f.element)};
      """

    self.hash_lookup_hash = Macro(std.size_t, {"target": self}, lambda target: str(self.index.hash( self.index.variable(f"(({target}).index)") )))
    self.hash_lookup_equal = Macro("int", {"left": self, "right": self}, lambda left, right: str(self.index.equal( self.index.variable(f"(({left}).index)"), self.index.variable(f"(({right}).index)") )))

    # The entries are identified by their indices alone so the ordered containers holding them
    # must compare them by the index as well
    with self.compare as f:
      f.code = f"""
        assert(left);
        assert(right);
        return {self.index.compare(self.index.variable("((left)->index)"), self.index.variable("((right)->index)"))};
      """
  
  @property
  def orderable(self):
    return True # the entries are ordered by their indices alone - the element is the payload

  @property
  def constructible(self):
    return False


# Common Forward range for mappings
class Range(_Range, Forward):

  brief = "Forward range over the mapping indices and elements"

  def __init__(self, iterable, *args, **kws):
    super().__init__(iterable, *args, **kws)
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
    front_doc = "the lowest index" if is_ordered else "the entry found first in the table layout"

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create the range spanning the whole mapping",
      description=f"""
        Creates the range over the mapping which starts at the first entry and
        proceeds {order_doc}. The range must not outlive the mapping and the mapping
        must not be modified while the range is traversed.

        @param[in] iterable the mapping to span
        @return the range covering the whole mapping {order_doc}
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
        The view is valid while that entry is held by the mapping.

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


# Abstract base class for all associative key-value maps backed by an underlying Set
class Mapping(_StructRenderer, Indexed):

  brief = "Abstract associative container mapping keys (indices) to values (elements) backed by an underlying set"

  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, index, *args, **kws)

  def _setup_range(self):
    self.range = Range(self)

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._set.variable("set").definition}; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

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

    if self.orderable:
      with self.compare as f:
        f.code = f"""
          assert(left);
          assert(right);
          return {self._set.compare(_left, _right)};
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

    with self.find_view as f:
      r = set.range.variable("r")
      f.code = f"""
        {r.definition};
        assert(target);
        for({r} = {set.range.new(_target)}; !{set.range.empty(r)}; {set.range.move_front(r)}) {{
          if({self.element.equal(entry.element_view(set.range.front_view(r)), f.element)}) {{
            return {entry.element_view(set.range.front_view(r))};
          }}
        }}
        return ({self.element.view_type})NULL;
      """

    with self.indexed as f:
      f.code = f"""
        assert(target);
        return {self.view(f.target, f.index)} != NULL;
      """

    with self.get as f:
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

    _entry = entry.variable("entry")

    with self.method("int", "remove", {"target": inout(self), "index": self.index}, brief="Remove entry with specified index",
      description="""
        Removes the key-value entry associated with `index` from the map, if present.

        @param[in,out] target the map to modify
        @param[in] index the key to remove
        @return 1 if an entry was removed, 0 if not found
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
