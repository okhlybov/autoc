from autoc.core import out, inout, Macro, Pointer
from autoc.composite import _StructRenderer
import autoc.std as std
from autoc.intrusive_hash_set import Set
from autoc.hash_map import _Entry
from autoc.map import Map


class _Entry(_Entry):
  
  def __init__(self, *args, is_empty, is_deleted, mark_empty, mark_deleted, **kws):
    super().__init__(*args, **kws)
    self.is_empty = Macro("int", {"entry": self}, is_empty)
    self.is_deleted = Macro("int", {"entry": self}, is_deleted)
    self.mark_empty = Macro(None, {"entry": inout(self)}, mark_empty)
    self.mark_deleted = Macro(None, {"entry": inout(self)}, mark_deleted)
    

#
class Map(_StructRenderer, Map):
  
  def __init__(self, name, element, index, *args, is_empty, is_deleted, mark_empty, mark_deleted, **kws):
    super().__init__(name, element, index, *args, **kws)
    self._set = Set(self._decorate_component("set", abbreviate=True),
        _Entry(self._decorate_component("entry", abbreviate=True), self.element, self.index, visibility="INTERNAL",
          is_empty=is_empty,
          is_deleted=is_deleted,
          mark_empty=mark_empty,
          mark_deleted=mark_deleted
    ), visibility="INTERNAL")
    self.depends(self._set)

  def __setup__(self):
    super().__setup__()

    _target = self.variable("target->set")
    _source = self.variable("source->set")
    _left = self.variable("left->set")
    _right = self.variable("right->set")
    
    with self.create as f:
      f.external = f"""
        assert(target);
        {self._set.create(_target)};
      """
    
    with self.destroy as f:
      f.external = f"""
        assert(target);
        {self._set.destroy(_target)};
      """
    
    with self.copy as f:
      f.external = f"""
        assert(target);
        assert(source);
        {self._set.copy(_target, _source)};
      """
        
    with self.equal as f:
      f.external = f"""
        assert(left);
        assert(right);
        return {self._set.equal(_left, _right)};
      """
    
    with self.hash as f:
      f.external = f"""
        assert(target);
        return {self._set.hash(_target)};
      """
    
    with self.empty as f:
      f.external = f"""
        assert(target);
        return {self._set.empty(_target)};
      """
    
    with self.size as f:
      f.external = f"""
        assert(target);
        return {self._set.size(_target)};
      """

    set = self._set
    entry = set.element
    _entry = entry.variable("entry")
    _entry_p = Pointer(entry).variable("entry_p")
    
    range = set.range
    r = range.variable("r")
    
    with self.contains as f:
      f.external = f"""
        {r.definition};
        assert(target);
        for(r = {range.new(_target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if({self.element.equal(entry.element_view(range.front_view(r)), f.element)}) return 1;
        }}
        return 0;
      """

    # FIXME get rid of the transient entry creation in the following code
      
    with self.indexed as f:
      f.external = f"""
        int result;
        {_entry.definition};
        assert(target);
        {entry.emplace_index(_entry, f.index)}; /* no element is required for the search operation */
        result = {set.contains(_target, _entry)};
        {entry.destroy_element(_entry)};
        return result;
      """
    
    with self.view as f:
      f.external = f"""
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
      _result = self.element.variable("result")
      f.external = f"""
        size_t i;
        {_element_p.definition};
        {_result.definition};
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {_element_p} = {self.view(f.target, f.index)};
        if({_element_p}) {{
          {self.element.copy(_result, _element_p)};
          return {_result};
        }} else abort();
      """
     
    with self.set as f:
      f.external = f"""
        size_t i;
        {_entry.definition};
        {_entry_p.definition};
        assert(target);
        /* emplace() codes do not destroy previous contents */
        {entry.emplace_index(_entry, f.index)}; /* no element is required for the search operation */
        entry_p = {set.locate_element(_target, "&i", _entry)}; /* try to find an existing entry with the specified index */
        if(entry_p) {{
          /* a set's entry with specified index already exists - replace its element's contents in-place */
          {entry.replace_element(_entry_p, f.element)};
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
