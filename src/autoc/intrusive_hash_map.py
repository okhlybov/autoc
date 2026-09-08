from autoc.map import Map
from autoc.hash_map import _Entry
from autoc.core import Indirection
from autoc.core import _StructRenderer, Callable
from autoc.collection import Range as _Range
from autoc.range import Forward
from autoc.intrusive_hash_set import Set


#
class Map(_StructRenderer, Map):
  
  def __init__(self, name, element, index, *args, is_empty, is_deleted, mark_empty, mark_deleted, **kws):
    super().__init__(name, element, index, *args, **kws)
    self._set = Set(
      self._decorate_component("set", abbreviate=True),
      _Entry(self._decorate_component("entry", abbreviate=True), self.element, self.index, visibility="internal"),
      visibility="internal",
      is_empty=is_empty,
      mark_empty=mark_empty,
      is_deleted=is_deleted,
      mark_deleted=mark_deleted,
    )
    self.dependencies.add(self._set)
    self.range = Range(self)

  @property
  def orderable(self):
    return False

  def __setup__(self):
    super().__setup__()

    _target = self.variable("target->set")
    _source = self.variable("source->set")
    _left = self.variable("left->set")
    _right = self.variable("right->set")
    
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
    _entry_p = Indirection(entry).variable("entry_p")
    
    range = set.range
    r = range.variable("r")
    
    with self.contains as f:
      f.code = f"""
        {r.definition};
        assert(target);
        for(r = {range.new(_target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if({self.element.equal(entry.element_view(range.front_view(r)), f.element)}) return 1;
        }}
        return 0;
      """

    # FIXME get rid of the transient entry creation in the following code
      
    with self.indexed as f:
      f.code = f"""
        int result;
        {_entry.definition};
        assert(target);
        {entry.emplace_index(_entry, f.index)}; /* no element is required for the search operation */
        result = {set.contains(_target, _entry)};
        {entry.destroy_element(_entry)};
        return result;
      """
    
    with self.view as f:
      f.code = f"""
        size_t i;
        {_entry.definition};
        {_entry_p.definition};
        assert(target);
        /* emplace() codes do not destroy previous contents */
        {entry.emplace_index(_entry, f.index)}; /* no element is required for the search operation */
        entry_p = {set.locate_element(_target, "&i", _entry)}; /* try to find an existing entry with the specified index */
        {entry.destroy_index(_entry)};
        return {entry.element_view(_entry_p)};
      """

    with self.get as f:
      _element_p = entry.element_p.variable("element_p")
      result = f.result.variable("result")
      f.code = f"""
        {_element_p.definition};
        {result.definition};
        assert(target);
        {_element_p} = ({_element_p.type}){self.view(f.target, f.index)};
        if({_element_p}) {{
          {self.element.copy(result, _element_p)};
          return {result};
        }} else abort();
      """
     
    with self.set as f:
      f.code = f"""
        size_t i;
        {_entry.definition};
        {_entry_p.definition};
        assert(target);
        /* emplace() codes do not destroy previous contents */
        {entry.emplace_index(_entry, f.index)}; /* no element is required for the search operation */
        entry_p = {set.locate_element(_target, "&i", _entry)}; /* try to find an existing entry with the specified index */
        if(entry_p) {{
          {entry.replace_element(_entry_p, f.element)}; /* a set's entry with specified index already exists - replace its element's contents in-place */
        }} else {{
          /* no entry with specified index exists in the set - put new fully initialized entry */
          {entry.emplace_element(_entry, f.element)}; /* set element field to finalize the entry */
          {set.put(_target, _entry)}; /* put brand new entry into the set */
          {entry.destroy_element(_entry)};
        }}
        {entry.destroy_index(_entry)};
      """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self._set.variable("set").definition}; /**< @private */
    }} {self.name};
    """)


#
class Range(_Range, Forward):

  def __init__(self, iterable, *args, **kws):
    super().__init__(iterable, *args, **kws)
    self._range = iterable._set.range
    self._entry = iterable._set.element
    self.index = iterable.index
    self.dependencies.update((self._entry, self._range))

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {self._range.name} range; /**< @private */
        }} {self.name};
      """)

  def __setup__(self):
    super().__setup__()

    _target_range = self._range.variable("target->range")

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}) as f:
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

    with self.method(self.index.view_type, ("index", "front", "view"), {"target": self}) as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self._entry.index_view(self._range.front_view(_target_range))};
      """

    with self.front as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self._entry.element_view(self._range.front_view(_target_range)).bind(f.result)};
      """

    with self.front_view as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self._entry.element_view(self._range.front_view(_target_range))};
      """

    with self.method(self.index, ("index", "front"), {"target": self}, constraint=lambda: self.index.copyable) as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self._entry.index_view(self._range.front_view(_target_range)).bind(f.result)};
      """

    with self.move_front as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        {self._range.move_front(_target_range)};
      """