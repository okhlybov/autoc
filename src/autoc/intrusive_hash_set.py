import autoc.std as std
from autoc.hash import Xor
from autoc.range import Forward
from autoc.core import _StructRenderer
from autoc.set import Set, _ceil_power2
from autoc.collection import Range as _Range
from autoc.core import out, inout, Macro, Indirection, Callable


class _Macro(Macro):

  def __init__(self, result, parameters, emitter, **kws):
    # Wrap the passthough arguments in () to circumvent operation proirity issues for user-supplied code
    super().__init__(result, parameters, lambda *args: emitter(*(f"({x})" for x in args)), **kws)


#
class Set(_StructRenderer, Set):
  
  def __init__(self, *args, capacity_threshold=0.75, hasher=Xor(), dependencies=(), is_empty, is_deleted, mark_empty, mark_deleted, **kws):
    super().__init__(*args, hasher=hasher, dependencies=(*dependencies, _ceil_power2), **kws)
    self._element_p = Indirection(self.element)
    self.capacity_threshold = capacity_threshold
    self.is_empty = _Macro("int", {"entry": self.element}, is_empty)
    self.is_deleted = _Macro("int", {"entry": self.element}, is_deleted)
    self.mark_empty = _Macro(None, {"entry": out(self.element)}, mark_empty)
    self.mark_deleted = _Macro(None, {"entry": out(self.element)}, mark_deleted)
    self.range = Range(self)

  @property
  def orderable(self):
    return False

  def __setup__(self):
    super().__setup__()
    
    target_i = self.element.variable("target->elements[index]")
    source_i = self.element.variable("source->elements[index]")
    target_elements = self._element_p.variable("target->elements")
    
    with self.size as f:
      f.inline_code = f"""
      assert(target);
      return target->size;
    """
    
    with self.method("int", ("is", "element"), {"element": self.element}, visibility="internal", hidden=True) as f:
      f.code = f"""
        return !({self.is_empty(f.element)} || {self.is_deleted(f.element)});
      """
    
    with self.method(None, "allocate", {"target": inout(self), "capacity": std.size_t}, hidden=True, visibility="internal") as f:
      f.code = f"""
        assert(target);
        assert(capacity > 0);
        target->size = 0;
        target->capacity = _autoc_ceil_power2(capacity);
        assert(!(target->capacity & (target->capacity - 1))); /* verify the capacity is a power of 2 */
        {target_elements} = {self.memory.allocate(self.element, "target->capacity")}; assert({target_elements});
      """
    
    _target = self.variable("_target")
    
    with self.method(None, ("create", "capacity"), {"target": out(self), "capacity": std.size_t}, hidden=True, visibility="internal") as f:
      f.code = f"""
        size_t index;
        assert(target);
        if(capacity) {{
          {self.allocate(f.target, f.capacity)};
          for(index = 0; index < target->capacity; ++index) {self.mark_empty(target_i)};
        }} else {{
          {self.create(f.target)};
        }}
      """

    with self.method(None, ("create", "size"), {"target": out(self), "size": std.size_t}) as f:
      f.code = f"""
        assert(target);
        {self.create_capacity(f.target, f"(size_t)({f.size}/{self.capacity_threshold})")};
      """

    with self.create as f:
      f.inline_code = f"""
        assert(target);
        target->elements = NULL;
        target->capacity = target->size = 0;
      """
    
    with self.method(Callable.Parameter(self._element_p), ("locate", "element"), {"target": self, "_index": out(std.size_t), "element": self.element}, visibility="internal", hidden=True, constraint=lambda: self.element.comparable) as f:
      f.code = f"""
        size_t index, start;
        {self._element_p} _element = NULL;
        assert(target);
        assert(_index);
        assert({self.is_element(f.element)});
        /* linear probing */
        if(target->elements) {{
          assert(target->capacity > 0);
          start = {self.element.hash_lookup_hash(f.element)} & (target->capacity-1); /* capacity is assumed to be the power of 2 */
          /* lookup terminator for the existing entry is an empty slot while deleted slot is not */
          for(index = start; index < target->capacity; ++index) {{
            if(!({self.is_empty(target_i)})) {{
              if(!({self.is_deleted(target_i)}) && {self.element.hash_lookup_equal(target_i, f.element)}) {{
                _element = &{target_i};
                goto stop;
              }}
            }} else goto stop;
          }}
          for(index = 0; index < start; ++index) {{
            if(!({self.is_empty(target_i)})) {{
              if(!({self.is_deleted(target_i)}) && {self.element.hash_lookup_equal(target_i, f.element)}) {{
                _element = &{target_i};
                goto stop;
              }}
            }} else goto stop;
          }}
          stop:
            *_index = index;
            return _element;
        }}
        return NULL;
      """
    
    with self.method(Callable.Parameter(self._element_p), ("locate", "slot"), {"target": self, "_index": out(std.size_t), "element": self.element}, visibility="internal", hidden=True, constraint=lambda: self.element.comparable) as f:
      f.code = f"""
        size_t index, start;
        assert(target);
        assert(_index);
        assert(target->capacity > 0);
        assert(target->size < target->capacity);
        assert({self.is_element(f.element)});
        /* linear probing */
        start = {self.element.hash_lookup_hash(f.element)} & (target->capacity-1); /* capacity is assumed to be the power of 2 */
        /* lookup terminator for non-existing entry is either empty or deleted slot */
        for(index = start; index < target->capacity; ++index) {{
          if(!{self.is_element(target_i)}) {{
            *_index = index;
            return &{target_i};
          }}
        }}
        for(index = 0; index < start; ++index) {{
          if(!{self.is_element(target_i)}) {{
            *_index = index;
            return &{target_i};
          }}
        }}
        abort(); /* not finding a suitable empty slot is a fatal error */
      """

    with self.method(None, "resize", {"target": inout(self), "new_size": std.size_t}, hidden=True, constraint=lambda: self.element.copyable) as f:
      f.code = f"""
        {_target.definition};
        size_t index, _index, new_capacity;
        assert(target);
        new_capacity = _autoc_ceil_power2((size_t)(new_size/{self.capacity_threshold})); /* predict new capacity after size changing respecting the desired capacity threshold */
        if(new_capacity < target->capacity && new_capacity < (size_t)(target->size/{self.capacity_threshold})) new_capacity = target->capacity; /* prevent the new capacity to fall below minimum required for original set's elements */
        if(new_capacity < 8) new_capacity = 8; /* enforce minimum viable capacity */
        assert(target->size <= new_capacity); /* require the new capacity to be large enough for the set to contain all original elements */
        if(new_capacity != target->capacity) {{
          {self.create_capacity(_target, "new_capacity")};
          if(target->elements) {{
            for(index = 0; index < target->capacity; ++index) {{
              if({self.is_element(target_i)}) {{
                {self.element.copy(self.locate_slot(_target, "&_index", target_i), target_i)}; /* direct planting in order to prevent from triggering the subsequent resizings */
              }}
            }}
            _target.size = target->size;
            {self.destroy(f.target)};
          }}
          *target = _target;
        }}
      """
    
    with self.contains as f:
      f.code = f"""
        size_t index;
        assert(target);
        assert({self.is_element(f.element)});
        return target->elements && {self.locate_element(f.target, "&index", f.element)} != NULL;
      """
    
    with self.destroy as f:
      if self.element.destructible:
        f.code = f"""
          size_t index;
          assert(target);
          if(target->elements) {{
            for(index = 0; index < target->capacity; ++index)
              if({self.is_element(target_i)})
                {self.element.destroy(target_i)};
            {self.memory.free(target_elements)};
          }}
        """
      else:
        f.code = f"""
          assert(target);
          if(target->elements) {{
            {self.memory.free(target_elements)};
          }}
        """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->size == 0;
      """
    
    with self.put as f:
      f.code = f"""
        size_t index;
        assert(target);
        assert({self.is_element(f.element)});
        if(!{self.contains(f.target, f.element)}) {{
          {self.resize(f.target, "target->size+1")};
          {self.element.copy(self.locate_slot(f.target, "&index", f.element), f.element)};
          ++target->size;
          return 1;
        }} else return 0;
      """
    
    with self.remove as f:
      _destroy = self.element.destroy(target_i) if self.element.destructible else str()
      f.code = f"""
        size_t index;
        assert(target);
        assert({self.is_element(f.element)});
        if({self.locate_element(f.target, "&index", f.element)}) {{
          {_destroy};
          {self.mark_deleted(target_i)};
          --target->size;
          return 1;
        }} else return 0;
      """
    
    with self.method(self.element.view_type, ("find", "view"), {"target": self, "element": self.element}) as f:
      f.code = f"""
        size_t index;
        assert(target);
        assert({self.is_element(f.element)});
        return {self.locate_element(f.target, "&index", f.element).bind(f.result)};
      """
    
    with self.copy as f:
      f.code = f"""
        size_t index;
        assert(target);
        assert(source);
        {self.create_size(f.target, "source->size")};
        for(index = 0; index < source->capacity; ++index) {{
          if({self.is_element(source_i)}) {{
            {self.put(f.target, source_i)};
          }}
        }}
      """

    range = self.range
    r = range.variable("r")
    
    with self.equal as f:
      f.code = f"""
        {r.definition};
        assert(left);
        assert(right);
        if({self.size(f.left)} == {self.size(f.right)}) {{
          for({r} = {range.new(f.left)}; !{range.empty(r)}; {range.move_front(r)}) {{
            if(!{self.contains(f.right, range.front_view(r))}) return 0;
          }}
          return 1;
        }} else return 0;
      """
    
    state = self.hasher.state_t.variable("state")
    
    with self.hash as f:
      f.code = f"""
        size_t result;
        {r.definition};
        {state.definition};
        assert(target);
        {self.hasher.create(state)};
        for({r} = {range.new(f.target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          {self.hasher.update(state, self.element.hash(range.front_view(r)))};
        }}
        result = {self.hasher.hash(state)};
        {self.hasher.destroy(state)};
        return result;
      """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self.element}* elements; /**< @private */
      {std.size_t} capacity; /**< @private */
      {std.size_t} size; /**< @private */
    }} {self.name};
    """)


#
class Range(_Range, Forward):
  
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Indirection(self.iterable, constant=True)} iterable; /**< @private */
          {std.size_t} front; /**< @private */
        }} {self.name};
      """)

  def _copy(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  def __setup__(self):
    super().__setup__()
    
    front_element = self.element.variable("target->iterable->elements[target->front]")

    with self.method(None, "next", {"target": inout(self)}, hidden=True, visibility="internal") as f:
      f.code = lambda: f"""
        assert(target);
        while(!{self.empty("target")} && !{self.iterable.is_element(front_element)}) ++target->front;
      """
    
    with self.method(Callable.Parameter(self), "new", {"iterable" : self.iterable}) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        {self.next("&result")};
        return {result};
      """

    with self.empty as f:
      f.code = f"""
        assert(target);
        return target->front >= target->iterable->capacity;
      """
    
    with self.front as f:
      result = f.result.variable("result")
      f.code = lambda: f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        assert({self.iterable.is_element(front_element)});
        {self.element.copy(result, front_element)};
        return {result};
      """
        
    with self.front_view as f:
      f.code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        assert({self.iterable.is_element(front_element)});
        return {front_element.bind(self.iterable.element.view_type)};
      """
    
    with self.move_front as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        ++target->front;
        {self.next(f.target)};
      """    