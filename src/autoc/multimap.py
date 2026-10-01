import autoc.std as std
from autoc.core import inout, Callable, Indirection, Macro
from autoc.container import _Range
from autoc.range import Forward
from autoc.record import Record
from autoc.multimapping import Multimapping
import autoc.core


# Common entry implementation for multimap backed by a set of (index -> collection)
class _Entry(Record):

  def __init__(self, name, collection, index, visibility, *args, **kws):
    super().__init__(name, {"index": index, "values": collection}, *args, visibility=visibility, **kws)
    self.index = self.fields["index"]
    self.values = self.fields["values"]
    self.element_p = self.values.view_type
    self.index_p = self.index.view_type

  @property
  def orderable(self):
    return self.index.orderable

  @property
  def hashable(self):
    return self.index.hashable

  @property
  def comparable(self):
    return self.index.comparable

  def __setup__(self):
    super().__setup__()

    _index = self.index.variable("target->index")
    _values = self.values.variable("target->values")

    with self.method(Callable.Parameter(self.element_p), ("element", "view"), {"target": self}, hidden=True, visibility="internal", brief="Get view of values collection (internal)") as f:
      f.code = f"""
        assert(target);
        return {self.values.variable("target->values").bind(f.result)};
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

    with self.method(None, ("emplace", "element"), {"target": inout(self), "element": self.values}, hidden=True, visibility="internal", constraint=lambda: self.values.copyable, brief="Emplace values collection (internal)") as f:
      f.code = f"""
        assert(target);
        {self.values.copy(_values, f.element)};
      """

    with self.method(None, ("destroy", "element"), {"target": inout(self)}, hidden=True, visibility="internal", brief="Destroy values collection (internal)") as f:
      if self.values.destructible:
        f.code = f"""
          assert(target);
          {self.values.destroy(_values)};
        """
      else:
        f.code = f"""
          assert(target);
        """

    self.hash_lookup_hash = Macro(std.size_t, {"target": self}, lambda target: str(self.index.hash( self.index.variable(f"(({target}).index)") )))
    self.hash_lookup_equal = Macro("int", {"left": self, "right": self}, lambda left, right: str(self.index.equal( self.index.variable(f"(({left}).index)"), self.index.variable(f"(({right}).index)") )))

    if self.orderable:
      with self.compare as f:
        f.code = f"""
          assert(left);
          assert(right);
          return {self.index.compare(self.index.variable("((left)->index)"), self.index.variable("((right)->index)"))};
        """


# Two-tier Forward range for generic multimaps
class Range(_Range, Forward):

  brief = "Forward range over the multimap indices and elements"

  def __init__(self, iterable, *args, dependencies=(), **kws):
    super().__init__(iterable, *args, dependencies=(*dependencies, std.assert_h), **kws)
    self._set_range = iterable._set.range
    self._col_range = iterable._collection.range
    self._entry = iterable._set.element
    self.index = iterable.index
    self.dependencies.update((self._entry, self._set_range, self._col_range))

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._set_range.name} set_r; /**< @private */
        {self._col_range.name} val_r; /**< @private */
        const {self.index}* cur_index; /**< @private */
        int valid; /**< @private */
        int single_key; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    set_r = self._set_range.variable("target->set_r")
    val_r = self._col_range.variable("target->val_r")
    set_range = self._set_range
    col_range = self._col_range
    entry = self._entry

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
        const {entry.name}* e;
        {result.definition};
        assert(iterable);
        result.single_key = 0;
        result.valid = 0;
        result.cur_index = NULL;
        result.set_r = {set_range.new(f"&{f.iterable}->set")};
        while(!{set_range.empty("&result.set_r")}) {{
          e = (const {entry.name}*){set_range.front_view("&result.set_r")};
          result.cur_index = {entry.index_view("e")};
          result.val_r = {col_range.new(entry.element_view("e"))};
          if(!{col_range.empty("&result.val_r")}) {{
            result.valid = 1;
            break;
          }}
          {set_range.move_front("&result.set_r")};
        }}
        return {result};
      """

    with self.empty as f:
      f.code = f"""
        assert(target);
        return !target->valid;
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
        assert(target->valid);
        return (const {self.index}*)target->cur_index;
      """

    with self.method(self.index, ("index", "front"), {"target": self}, constraint=lambda: self.index.copyable, brief="Get front index",
      description=f"""
        Returns a copy of the index of {front_doc}.

        @param[in] target the non-empty range to inspect
        @return a copy of the front index
      """) as f:
      result = f.result.variable("result")
      index_src = self.index.variable("(*target->cur_index)") if isinstance(self.index, autoc.core.Primitive) else self.index.view_type.variable("target->cur_index")
      f.code = f"""
        {result.definition};
        assert(target);
        assert(target->valid);
        {self.index.copy(result, index_src)};
        return {result};
      """

    with self.front_view as f:
      f.code = f"""
        assert(target);
        assert(target->valid);
        return {col_range.front_view(val_r)};
      """

    with self.front as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(target);
        assert(target->valid);
        {self.element.copy(result, col_range.front_view(val_r))};
        return {result};
      """

    with self.move_front as f:
      f.code = f"""
        const {entry.name}* e;
        assert(target);
        assert(target->valid);
        {col_range.move_front(val_r)};
        if(!{col_range.empty(val_r)}) return;
        if(target->single_key) {{
          target->valid = 0;
          return;
        }}
        {set_range.move_front(set_r)};
        while(!{set_range.empty(set_r)}) {{
          e = (const {entry.name}*){set_range.front_view(set_r)};
          target->cur_index = {entry.index_view("e")};
          target->val_r = {col_range.new(entry.element_view("e"))};
          if(!{col_range.empty(val_r)}) return;
          {set_range.move_front(set_r)};
        }}
        target->valid = 0;
      """


#
class Map(Multimapping):

  brief = "Generic associative multimap container parameterized by a set and a collection container"

  def __init__(self, name, element, index, set, collection, *args, dependencies=(), **kws):
    super().__init__(name, element, index, *args, dependencies=(*dependencies, std.assert_h, std.stdlib_h), **kws)
    self._collection = collection(
      self._decorate_component("collection", abbreviate=True),
      self.element,
      visibility="internal",
    )
    self._entry = _Entry(
      self._decorate_component("entry", abbreviate=True),
      self._collection,
      self.index,
      visibility="internal",
    )
    self._set = set(
      self._decorate_component("set", abbreviate=True),
      self._entry,
      visibility="internal",
      algebraic_operations=False,
    )
    self.dependencies.update((self._collection, self._entry, self._set))
    self.range = Range(self)

  @property
  def orderable(self):
    return self._set.orderable

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._set.variable("set").definition}; /**< @private */
        size_t size; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Generic multimap parameterized by key set container (@ref {self._set}) and value collection (@ref {self._collection}).
      Supports one-way traversal over the keys and elements via the corresponding @ref {self.range} iterator.
    """

    set = self._set
    entry = self._entry
    col = self._collection
    _probe = entry.variable("probe")

    _target = set.variable("target->set")
    _source = set.variable("source->set")
    _left = set.variable("left->set")
    _right = set.variable("right->set")

    with self.create as f:
      f.code = f"""
        assert(target);
        {set.create(_target)};
        target->size = 0;
      """

    with self.destroy as f:
      f.code = f"""
        assert(target);
        {set.destroy(_target)};
      """

    with self.copy as f:
      f.code = f"""
        assert(target);
        assert(source);
        {set.copy(_target, _source)};
        target->size = source->size;
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        {set.move(_target, _source)};
        target->size = source->size;
        source->size = 0;
      """

    with self.equal as f:
      f.code = f"""
        assert(left);
        assert(right);
        if(left->size != right->size) return 0;
        return {set.equal(_left, _right)};
      """

    with self.hash as f:
      f.code = f"""
        assert(target);
        return {set.hash(_target)};
      """

    with self.empty as f:
      f.code = f"""
        assert(target);
        return target->size == 0;
      """

    with self.size as f:
      f.code = f"""
        assert(target);
        return target->size;
      """

    if self.orderable:
      with self.compare as f:
        f.code = f"""
          assert(left);
          assert(right);
          return {set.compare(_left, _right)};
        """

    # Helper snippet for values insertion
    # Sequences use push_back, push, or push_front; Sets/Multisets use put
    if hasattr(col, "push_back"):
      col_insert = lambda c_ptr, val: f"{col.push_back(c_ptr, val)}"
    elif hasattr(col, "push"):
      col_insert = lambda c_ptr, val: f"{col.push(c_ptr, val)}"
    elif hasattr(col, "push_front"):
      col_insert = lambda c_ptr, val: f"{col.push_front(c_ptr, val)}"
    else:
      col_insert = lambda c_ptr, val: f"{col.put(c_ptr, val)}"

    # Helper snippet for values removal
    if hasattr(col, "pop_front"):
      col_remove = lambda c_ptr: f"{col.pop_front(c_ptr)}"
    elif hasattr(col, "pop"):
      col_remove = lambda c_ptr: f"{col.pop(c_ptr)}"
    elif hasattr(col, "pop_back"):
      col_remove = lambda c_ptr: f"{col.pop_back(c_ptr)}"
    elif hasattr(col, "remove"):
      col_remove = lambda c_ptr, val: f"{col.remove(c_ptr, val)}"
    else:
      col_remove = None

    with self.find_view as f:
      r = set.range.variable("r")
      f.code = f"""
        {r.definition};
        const {entry.name}* e;
        {self.element.view_type} fv;
        assert(target);
        for({r} = {set.range.new(_target)}; !{set.range.empty(r)}; {set.range.move_front(r)}) {{
          e = (const {entry.name}*){set.range.front_view(r)};
          fv = {col.find_view(entry.element_view("e"), f.element)};
          if(fv) return fv;
        }}
        return ({self.element.view_type})NULL;
      """

    with self.view as f:
      found = Indirection(entry, constant=True).variable("found")
      vr = col.range.variable("vr")
      f.code = f"""
        {_probe.definition};
        {found.definition};
        assert(target);
        {entry.create(_probe)};
        {self.index.copy(self.index.variable("probe.index"), f.index)};
        {found} = (const {entry.name}*){set.find_view(_target, _probe)};
        {entry.destroy(_probe)};
        if({found} && !{col.empty(entry.element_view(found))}) {{
          {vr.definition} = {col.range.new(entry.element_view(found))};
          return {col.range.front_view(vr)};
        }}
        return ({self.element.view_type})NULL;
      """

    with self.indexed as f:
      f.code = f"""
        assert(target);
        return {self.view(f.target, f.index)} != NULL;
      """

    with self.get as f:
      result = f.result.variable("result")
      element_view = self.element.view_type.variable("elem_p")
      f.code = f"""
        {result.definition};
        {element_view.definition};
        assert(target);
        {element_view} = {self.view(f.target, f.index)};
        if(!{element_view}) abort();
        {self.element.copy(result, element_view)};
        return {result};
      """

    with self.put as f:
      found = Indirection(entry, constant=True).variable("found")
      f.code = f"""
        {_probe.definition};
        {found.definition};
        assert(target);
        {entry.create(_probe)};
        {self.index.copy(self.index.variable("probe.index"), f.index)};
        {found} = (const {entry.name}*){set.find_view(_target, _probe)};
        if({found}) {{
          {col_insert(f"&(({entry.name}*){found})->values", f.element)};
          {entry.destroy(_probe)};
        }} else {{
          {col_insert(self.values_variable("probe.values") if hasattr(self, "values_variable") else "&probe.values", f.element)};
          {set.put(_target, _probe)};
          {entry.destroy(_probe)};
        }}
        ++target->size;
        return 1;
      """

    with self.count as f:
      found = Indirection(entry, constant=True).variable("found")
      f.code = f"""
        {_probe.definition};
        {found.definition};
        size_t cnt;
        assert(target);
        {entry.create(_probe)};
        {self.index.copy(self.index.variable("probe.index"), f.index)};
        {found} = (const {entry.name}*){set.find_view(_target, _probe)};
        {entry.destroy(_probe)};
        cnt = {found} ? {col.size(entry.element_view(found))} : 0;
        return cnt;
      """

    with self.remove as f:
      found = Indirection(entry, constant=True).variable("found")
      if col_remove:
        rem_code = f"""
          {col_remove(f"&(({entry.name}*){found})->values")};
          --target->size;
          if({col.empty(entry.element_view(found))}) {{
            {set.remove(_target, _probe)};
          }}
          {entry.destroy(_probe)};
          return 1;
        """
      else:
        rem_code = f"""
          {entry.destroy(_probe)};
          return 0;
        """
      f.code = f"""
        {_probe.definition};
        {found.definition};
        assert(target);
        {entry.create(_probe)};
        {self.index.copy(self.index.variable("probe.index"), f.index)};
        {found} = (const {entry.name}*){set.find_view(_target, _probe)};
        if({found}) {{
          {rem_code}
        }}
        {entry.destroy(_probe)};
        return 0;
      """

    with self.wipe as f:
      found = Indirection(entry, constant=True).variable("found")
      f.code = f"""
        {_probe.definition};
        {found.definition};
        size_t wiped;
        assert(target);
        {entry.create(_probe)};
        {self.index.copy(self.index.variable("probe.index"), f.index)};
        {found} = (const {entry.name}*){set.find_view(_target, _probe)};
        if({found}) {{
          wiped = {col.size(entry.element_view(found))};
          target->size -= wiped;
          {set.remove(_target, _probe)};
          {entry.destroy(_probe)};
          return wiped;
        }}
        {entry.destroy(_probe)};
        return 0;
      """

    with self.equal_range as f:
      result = f.result.variable("result")
      found = Indirection(entry, constant=True).variable("found")
      f.code = f"""
        {result.definition};
        {_probe.definition};
        {found.definition};
        assert(target);
        result.single_key = 1;
        result.valid = 0;
        result.cur_index = NULL;
        {entry.create(_probe)};
        {self.index.copy(self.index.variable("probe.index"), f.index)};
        {found} = (const {entry.name}*){set.find_view(_target, _probe)};
        {entry.destroy(_probe)};
        if({found} && !{col.empty(entry.element_view(found))}) {{
          result.cur_index = {entry.index_view(found)};
          result.val_r = {col.range.new(entry.element_view(found))};
          if(!{col.range.empty("&result.val_r")}) {{
            result.valid = 1;
          }}
        }}
        return {result};
      """