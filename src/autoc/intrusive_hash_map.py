from autoc.mapping import Mapping, _Entry
from autoc.intrusive_hash_set import Set
from autoc.hashed import Hashed


#
class Map(Mapping, Hashed):
  
  brief = "Map from index to element over open addressing with sentinel values"

  def __init__(self, name, element, index, *args, is_empty, is_deleted, mark_empty, mark_deleted, **kws):
    super().__init__(name, element, index, *args, **kws)
    self._set = Set(
      self._decorate_component("set", abbreviate=True),
      _Entry(self._decorate_component("entry", abbreviate=True), self.element, self.index, visibility="internal"),
      visibility="internal",
      algebraic_operations=False,
      is_empty=is_empty,
      mark_empty=mark_empty,
      is_deleted=is_deleted,
      mark_deleted=mark_deleted,
    )
    self.dependencies.add(self._set)
    self._setup_range()

  @property
  def orderable(self):
    return False

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the index type (@ref {self.index}) to be *Hashable*, *Comparable* and to reserve
      the two sentinel states - the empty and the deleted slots of the table -
      and the element type (@ref {self.element}) to be *Copyable*.
      Supports one way traversal over the indices and elements via the corresponding @ref {self.range} iterator.

      Implemented as the hash table with the flat open addressing over the sentinel carrying entries.
      The closest C++ equivalent is [std::unordered_map<>](https://cppreference.com/cpp/container/unordered_map).
    """

    set = self._set
    entry = set.element
    _entry = entry.variable("entry")
    _target = self._set.variable("target->set")
    slot = entry.variable("target->set.elements[i]")
    slot_index = self.index.variable("target->set.elements[i].index")

    with self.view as f:
      f.code = f"""
        /*
          Direct open-addressing lookup without transient entry allocation:
          Hashes the search index directly and probes slots using the index comparator
          and sentinel checks, avoiding stack-allocated dummy entry copies.
        */
        size_t i, start;
        assert(target);
        if(target->set.elements) {{
          assert(target->set.capacity > 0);
          start = {self.index.hash(f.index)} & (target->set.capacity - 1);
          for(i = start; i < target->set.capacity; ++i) {{
            if(!({set.is_empty(slot)})) {{
              if(!({set.is_deleted(slot)}) && {self.index.equal(slot_index, f.index)}) {{
                return {entry.element_view(slot).bind(self.element.view_type)};
              }}
            }} else goto not_found;
          }}
          for(i = 0; i < start; ++i) {{
            if(!({set.is_empty(slot)})) {{
              if(!({set.is_deleted(slot)}) && {self.index.equal(slot_index, f.index)}) {{
                return {entry.element_view(slot).bind(self.element.view_type)};
              }}
            }} else goto not_found;
          }}
        }}
        not_found:
        return ({self.element.view_type})NULL;
      """

    with self.set as f:
      f.code = f"""
        /*
          Direct open-addressing search to replace existing element in-place,
          or insert a new entry into the set if absent.
        */
        size_t i, start;
        {_entry.definition};
        assert(target);
        if(target->set.elements) {{
          assert(target->set.capacity > 0);
          start = {self.index.hash(f.index)} & (target->set.capacity - 1);
          for(i = start; i < target->set.capacity; ++i) {{
            if(!({set.is_empty(slot)})) {{
              if(!({set.is_deleted(slot)}) && {self.index.equal(slot_index, f.index)}) {{
                {entry.replace_element(slot, f.element)};
                return;
              }}
            }} else goto do_insert;
          }}
          for(i = 0; i < start; ++i) {{
            if(!({set.is_empty(slot)})) {{
              if(!({set.is_deleted(slot)}) && {self.index.equal(slot_index, f.index)}) {{
                {entry.replace_element(slot, f.element)};
                return;
              }}
            }} else goto do_insert;
          }}
        }}
        do_insert:
        {entry.emplace_index(_entry, f.index)};
        {entry.emplace_element(_entry, f.element)};
        {set.put(_target, _entry)};
        {entry.destroy_element(_entry)};
        {entry.destroy_index(_entry)};
      """

    with self.emplace as f:
      create_args = [getattr(f, name) for name in self.element.constructor_parameters]
      f.code = f"""
        size_t i, start;
        {_entry.definition};
        assert(target);
        if(target->set.capacity > 0) {{
          start = {self.index.hash(f.index)} & (target->set.capacity - 1);
          for(i = start; i < target->set.capacity; ++i) {{
            if(!({set.is_empty(slot)})) {{
              if(!({set.is_deleted(slot)}) && {self.index.equal(slot_index, f.index)}) {{
                return 0;
              }}
            }} else goto do_emplace_insert;
          }}
          for(i = 0; i < start; ++i) {{
            if(!({set.is_empty(slot)})) {{
              if(!({set.is_deleted(slot)}) && {self.index.equal(slot_index, f.index)}) {{
                return 0;
              }}
            }} else goto do_emplace_insert;
          }}
        }}
        do_emplace_insert:
        {entry.emplace_index(_entry, f.index)};
        {entry.create_element(_entry, *create_args)};
        {set.put(_target, _entry)};
        {entry.destroy_element(_entry)};
        {entry.destroy_index(_entry)};
        return 1;
      """