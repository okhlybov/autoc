from autoc.map import Map
from autoc.treap_set import Set
from autoc.range import Forward
from autoc.hash_map import _Entry
from autoc.collection import _Range
from autoc.core import _StructRenderer
from autoc.core import Indirection, Callable


#
class Map(_StructRenderer, Map):

  brief = "Ordered map from index to element implemented as a treap - iterates in index order"
  
  def __init__(self, name, element, index, *args, **kws):
    super().__init__(name, element, index, *args, **kws)
    self._set = Set(
      self._decorate_component("set", abbreviate=True),
      _Entry(self._decorate_component("entry", abbreviate=True), self.element, self.index, visibility="internal"),
      visibility="internal",
    )
    self.dependencies.add(self._set)
    self.range = Range(self)

  @property
  def orderable(self):
    # The treap map is an ordered container: the entries are iterated and compared by their indices
    return True

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the index type (@ref {self.index}) to be *Orderable* and the element type (@ref {self.element}) to be *Copyable*.
      Supports one way traversal over the indices and elements via the corresponding @ref {self.range} iterator - the entries are yielded in index order.

      Implemented as the treap - the randomized binary search tree over the internal entry set.
      The closest C++ equivalent is [std::map<>](https://cppreference.com/cpp/container/map).
    """

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

    # The maps are equal when they hold the same indices - the treap map follows the same
    # convention while the ordering is the index ordering as well
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
    _entry = entry.variable("entry")
    n = Indirection(set.node).variable("n")
    node_entry = entry.variable("n->element")
    node_index = entry.index.variable("n->element.index")

    with self.contains as f:
      f.code = f"""
        {set.range.variable("r").definition};
        assert(target);
        for({set.range.variable("r")} = {set.range.new(_target)}; !{set.range.empty(set.range.variable("r"))}; {set.range.move_front(set.range.variable("r"))}) {{
          if({self.element.equal(entry.element_view(set.range.front_view(set.range.variable("r"))), f.element)}) return 1;
        }}
        return 0;
      """

    # The lookups walk the tree directly comparing the indices - no transient entries are needed
    # while the insertions reuse the treap set machinery wholesale
    with self.indexed as f:
      f.code = f"""
        int order;
        {n.definition};
        assert(target);
        n = target->set.root;
        while(n) {{
          order = {self.index.compare(node_index, f.index)};
          if(order == 0) return 1;
          n = order > 0 ? n->left : n->right;
        }}
        return 0;
      """

    with self.view as f:
      f.code = f"""
        int order;
        {n.definition};
        assert(target);
        n = target->set.root;
        while(n) {{
          order = {self.index.compare(node_index, f.index)};
          if(order == 0) return {entry.element_view(node_entry).bind(self.element.view_type)};
          n = order > 0 ? n->left : n->right;
        }}
        return ({self.element.view_type})0;
      """

    with self.get as f:
      result = f.result.variable("result")
      f.code = f"""
        int order;
        {n.definition};
        {result.definition};
        assert(target);
        n = target->set.root;
        while(n) {{
          order = {self.index.compare(node_index, f.index)};
          if(order == 0) break;
          n = order > 0 ? n->left : n->right;
        }}
        if(!n) abort();
        {self.element.copy(result, entry.element_view(node_entry))};
        return {result};
      """

    with self.set as f:
      f.code = f"""
        int order;
        {n.definition};
        {_entry.definition};
        assert(target);
        n = target->set.root;
        while(n) {{
          order = {self.index.compare(node_index, f.index)};
          if(order == 0) break;
          n = order > 0 ? n->left : n->right;
        }}
        if(n) {{
          {entry.replace_element(node_entry, f.element)}; /* an entry with the specified index already exists - replace its element's contents in-place */
        }} else {{
          {entry.emplace_index(_entry, f.index)};
          {entry.emplace_element(_entry, f.element)};
          {set.put(_target, _entry)}; /* put the brand new entry into the treap */
          {entry.destroy_element(_entry)};
          {entry.destroy_index(_entry)};
        }}
      """

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._set.variable("set").definition}; /**< @private */
      }};
    """)


#
class Range(_Range, Forward):

  brief = "Forward range over the map indices and elements"

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

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create the range spanning the whole map",
      description="""
        Creates the range over the treap backed map which starts at the lowest index and
        proceeds in ascending index order. The range must not outlive the map and the map
        must not be modified while the range is traversed.

        @param[in] iterable the map to span
        @return the range covering the whole map in index order
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
      description="""
        Returns a pointer to the index of the leftmost entry - the one with the lowest
        index. The view is valid while that entry is held by the map.

        @param[in] target the non-empty range to inspect
        @return a constant view of the front (lowest) index
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
      description="""
        Returns a copy of the index of the leftmost entry - the one with the lowest index.

        @param[in] target the non-empty range to inspect
        @return a copy of the front (lowest) index
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
