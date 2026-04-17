import autoc.set
import autoc.core
import autoc.hash
import autoc.std as std
from autoc.core import out, inout, Pointer

#
class IntrusiveHashSet(autoc.composite._StructRenderer, autoc.set.Set):
  
  def __init__(self, *args, dependencies=[], capacity_threshold=0.75, **kws):
    super().__init__(*args, hasher=autoc.hash.Xor(), dependencies=[*dependencies, autoc.set.ceil_power2], **kws)
    self._element_p = Pointer(self.element)
    self.capacity_threshold = capacity_threshold
    
  def __setup__(self):
    super().__setup__()
    
    self.test_empty = self._test_empty("int", {"element": self.element})
    self.mark_empty = self._mark_empty(None, {"element": inout(self.element)})

    self.test_deleted = self._test_deleted("int", {"element": self.element})
    self.mark_deleted = self._mark_deleted(None, {"element": inout(self.element)})

    element = self.element.variable("element")
    target_i = self.element.variable("target->elements[index]")
    source_i = self.element.variable("source->elements[index]")
    target_elements = Pointer(self.element).variable("target->elements")
    
    self.size.linkage = "INLINE"
    self.size.code = f"""
      assert(target);
      return target->size;
    """
    self._inline_policy(self.size)
    
    self.test_element = self.method("int", ("test", "element"), {"element": self.element}, visibility="PRIVATE", hidden=True)
    self.test_element.code = f"""
      return !({self.test_empty(element)} || {self.test_deleted(element)});
    """
    self._inline_policy(self.test_element)
    
    self.allocate = self.method(None, "allocate", {"target": inout(self), "capacity": std.size_t}, hidden=True, visibility="PRIVATE")
    self.allocate.code = f"""
      assert(target);
      assert(capacity > 0);
      target->size = 0;
      target->capacity = _autoc_ceil_power2(capacity);
      assert(!(target->capacity & (target->capacity - 1))); /* verify the capacity is a power of 2 */
      {target_elements} = {self.memory.allocate(self.element, "target->capacity")}; assert({target_elements});
    """
    self._inline_policy(self.allocate)
    
    _target = self.variable("_target")
    
    self.create_size = self.method(None, ("create", "size"), {"target": out(self), "size": std.size_t})
    self.create_size.code = f"""
      size_t index;
      assert(target);
      if(size) {{
        {self.allocate("target", f"size/{self.capacity_threshold}")};
        for(index = 0; index < target->capacity; ++index) {self.mark_empty(target_i)};
      }} else {{
        {self.create("target")};
      }}
    """
    self._inline_policy(self.create_size)
    
    self.manage_storage = self.method(None, ("manage", "storage"), {"target": inout(self), "new_size": std.size_t}, hidden=True, visibility="PRIVATE")
    self.manage_storage.code = f"""
      {_target.definition};
      size_t index;
      assert(target);
      if(!target->elements || (new_size > target->size && new_size > {self.capacity_threshold}*target->capacity)) {{
        {self.create_size(_target, "new_size")};
        if(target->elements) {{
          for(index = 0; index < target->capacity; ++index) {{
            if({self.test_element(target_i)}) {{
              {self.put(_target, target_i)};
            }}
          }}
          {self.destroy("target")};
        }}
        *target = _target;
      }}
    """
    self._inline_policy(self.manage_storage)
    
    self.create.linkage = "INLINE"
    self.create.code = f"""
      assert(target);
      target->elements = NULL;
      target->capacity = target->size = 0;
    """
    self._inline_policy(self.create)
    
    self.locate_element = self.method(self._element_p, ("locate", "element"), {"target": self, "_index": out(std.size_t), "element": self.element}, visibility="PRIVATE", hidden=True)
    self.locate_element.code=f"""
      size_t index, start;
      {self._element_p} _element = NULL;
      assert(target);
      assert(_index);
      assert(target->capacity > 0);
      assert({self.test_element(element)});
      /* linear probing */
      start = {self.element.hash(self.locate_element.element)} & (target->capacity-1); /* capacity is assumed to be the power of 2 */
      /* when looking for specific element the lookup terminator is an empty slot while deleted slot is not */
      for(index = start; index < target->capacity; ++index) {{
        if(!({self.test_empty(target_i)})) {{
          if(!({self.test_deleted(target_i)}) && {self.element.equal(target_i, self.locate_element.element)}) {{
            _element = &{target_i};
            goto stop;
          }}
        }} else goto stop;
      }}
      for(index = 0; index < start; ++index) {{
        if(!({self.test_empty(target_i)})) {{
          if(!({self.test_deleted(target_i)}) && {self.element.equal(target_i, self.locate_element.element)}) {{
            _element = &{target_i};
            goto stop;
          }}
        }} else goto stop;
      }}
      stop:
        *_index = index;
        return _element;
    """
    self._inline_policy(self.locate_element)
    
    self.locate_slot = self.method(self._element_p, ("locate", "slot"), {"target": self, "_index": out(std.size_t), "element": self.element}, visibility="PRIVATE", hidden=True)
    self.locate_slot.code=f"""
      size_t index, start;
      assert(target);
      assert(_index);
      assert(target->capacity > 0);
      assert(target->size < target->capacity);
      assert({self.test_element(element)});
      /* linear probing */
      start = {self.element.hash(self.locate_slot.element)} & (target->capacity-1); /* capacity is assumed to be the power of 2 */
      /* a slot for the new element is either empty or deleted */
      for(index = start; index < target->capacity; ++index) {{
        if(!{self.test_element(target_i)}) {{
          *_index = index;
          return &{target_i};
        }}
      }}
      for(index = 0; index < start; ++index) {{
        if(!{self.test_element(target_i)}) {{
          *_index = index;
          return &{target_i};
        }}
      }}
      abort(); /* not finding a suitable empty slot is a fatal error */
    """
    self._inline_policy(self.locate_slot)

    self.contains = self.method("int", "contains", {"target": self, "element": self.element})
    self.contains.code = f"""
      size_t index;
      assert(target);
      assert({self.test_element(element)});
      return target->elements && {self.locate_element("target", "&index", self.contains.element)} != NULL;
    """
    self._inline_policy(self.contains)
    
    destroy = f"""
      for(index = 0; index < target->capacity; ++index)
        if({self.test_element(target_i)})
          {self.element.destroy(target_i)};
    """ if self.element.destructible else str()
    
    self.destroy.code = f"""
      size_t index;
      assert(target);
      if(target->elements) {{
        {destroy};
        {self.memory.free(target_elements)};
      }}
    """
    self._inline_policy(self.destroy)

    self.empty.linkage = "INLINE"
    self.empty.code = f"""
      assert(target);
      return target->size == 0;
    """
    self._inline_policy(self.empty)
    
    self.put.code = f"""
      size_t index;
      {self.element_view} _element;
      assert(target);
      assert({self.test_element(element)});
      if(!{self.contains("target", self.put.element)}) {{
        {self.manage_storage("target", "target->size+1")};
        {self.element.copy(self.locate_slot("target", "&index", self.put.element), self.put.element)};
        ++target->size;
        return 1;
      }} else return 0;
    """
    self._inline_policy(self.put)
    
    self.find_view = self.method(self.element_view, ("find", "view"), {"target": self, "element": self.element})
    self.find_view.code = f"""
      size_t index;
      assert(target);
      assert({self.test_element(element)});
      return {self.locate_element("target", "&index", self.find_view.element)};
    """
    self._inline_policy(self.find_view)
    
    self.copy.code = f"""
      size_t index;
      assert(target);
      assert(source);
      {self.create_size("target", "source->size")};
      for(index = 0; index < source->capacity; ++index) {{
        if({self.test_element(source_i)}) {{
          {self.put("target", source_i)};
        }}
      }}
    """
    self._inline_policy(self.copy)

    self.range = Range(self)
    self.references.add(self.range)
    
    range = self.range
    r = range.variable("r")
    
    self.equal.code = f"""
      {r.definition};
      assert(left);
      assert(right);
      if({self.size("left")} == {self.size("right")}) {{
        for({r} = {range.new("left")}; !{range.empty(r)}; {range.move_front(r)}) {{
          if(!{self.contains("right", range.front_view(r))}) return 0;
        }}
        return 1;
      }} else return 0;
    """
    
    state = self.hasher.state_t.variable("state")
    
    self.hash.code = f"""
      size_t result;
      {r.definition};
      {state.definition};
      assert(target);
      {self.hasher.create("state")};
      for({r} = {range.new("target")}; !{range.empty(r)}; {range.move_front(r)}) {{
        {self.hasher.update(state, self.element.hash(range.front_view(r)))};
      }}
      result = {self.hasher.hash(state)};
      {self.hasher.destroy(state)};
      return result;
    """
    

  def _render_struct(self, stream):
    if self.public:
      stream.append("/** @public */\n")
    if self.private:
      stream.append("/** @private */\n")
    stream.append(f"""typedef struct {{
      {self.element}* elements; /**< @private */
      {std.size_t} capacity; /**< @private */
      {std.size_t} size; /**< @private */
    }} {self.name};
    """)


#
class Range(autoc.range.Forward):
  
  def __init__(self, iterable, *args, **kws):
    super().__init__(iterable.element, iterable.decorate("range"), **kws)
    self.iterable = iterable
    self.depends(iterable)

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Pointer(self.iterable, constant=True)} iterable; /**< @private */
          {std.size_t} front; /**< @private */
        }} {self.name};
      """)

  def _copy(self, result, parameters, **kws):
    return autoc.core.Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  def __setup__(self):
    super().__setup__()
    
    self.new = self.method(self, "new", {"iterable" : self.iterable})

    target = self.variable("target")
    front_element = self.element.variable("target->iterable->elements[target->front]")

    self.next = self.method(None, "next", {"target": inout(self)}, hidden=True, visibility="PRIVATE", linkage="INLINE", code=f"""
      assert(target);
      while(!{self.empty("target")} && !{self.iterable.test_element(front_element)}) ++target->front;
    """)
    
    self.new.linkage = "INLINE"
    self.new.code = f"""
      {self} result = {{ iterable, 0 }};
      assert(iterable);
      {self.next("&result")};
      return result;
    """

    self.empty.linkage = "INLINE"
    self.empty.code = f"""
      assert(target);
      return target->front >= target->iterable->capacity;
    """

    result = self.element.variable("result")
    
    self.front.linkage = "INLINE"
    self.front.code = f"""
      {result.definition};
      assert(target);
      assert(!{self.empty("target")});
      assert({self.iterable.test_element(front_element)});
      {self.element.copy(result, front_element)};
      return result;
    """
        
    self.front_view.linkage = "INLINE"
    self.front_view.code = f"""
      assert(target);
      assert(!{self.empty("target")});
      assert({self.iterable.test_element(front_element)});
      return ({self.iterable.element_view})&{front_element};
    """
    
    self.move_front.linkage = "INLINE"
    self.move_front.code = f"""
      assert(target);
      assert(!{self.empty("target")});
      ++target->front;
      {self.next("target")};
    """    