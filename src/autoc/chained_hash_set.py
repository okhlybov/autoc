import autoc.std as std
from autoc.range import Forward
from autoc.set import Set, _ceil_power2
from autoc.collection import Range as _Range
from autoc.core import inout, out, _type, _StructRenderer, Indirection, Callable


#
class Set(_StructRenderer, Set):

  def __init__(self, *args, capacity_threshold=1.0, dependencies=(), **kws):
    super().__init__(*args, dependencies=(*dependencies, _ceil_power2), **kws)
    self.node = _type(self._decorate_component("node"))
    self._node_p = Indirection(self.node)
    self._bucket_p = Indirection(self._node_p)
    self.capacity_threshold = capacity_threshold
    self.range = Range(self)

  @property
  def orderable(self):
    return False

  def __setup__(self):
    super().__setup__()

    node_element = self.element.variable("n->element")
    source_element = self.element.variable("source_n->element")
    target_element = self.element.variable("n->element")
    with self.size as f:
      f.inline_code = f"""
        assert(target);
        return target->size;
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->size == 0;
      """

    with self.create as f:
      f.inline_code = f"""
        assert(target);
        target->buckets = NULL;
        target->capacity = target->size = 0;
      """

    with self.method(None, "allocate", {"target": inout(self), "capacity": std.size_t}, hidden=True, visibility="internal") as f:
      f.code = f"""
        assert(target);
        assert(capacity > 0);
        target->capacity = _autoc_ceil_power2(capacity);
        target->buckets = {self.memory.allocate(self._node_p, "target->capacity", zero=True)}; assert(target->buckets);
        target->size = 0;
      """

    with self.method(None, ("create", "capacity"), {"target": out(self), "capacity": std.size_t}, hidden=True, visibility="internal") as f:
      f.code = f"""
        assert(target);
        if(capacity) {{
          {self.allocate(f.target, f.capacity)};
        }} else {{
          {self.create(f.target)};
        }}
      """

    with self.method(None, ("create", "size"), {"target": out(self), "size": std.size_t}) as f:
      f.code = f"""
        assert(target);
        {self.create_capacity(f.target, f"(size_t)({f.size}/{self.capacity_threshold})")};
      """

    with self.destroy as f:
      _destroy = self.element.destroy(node_element) if self.element.destructible else str()
      f.code = f"""
        size_t index;
        {self.node}* n;
        {self.node}* _n;
        assert(target);
        if(target->buckets) {{
          for(index = 0; index < target->capacity; ++index) {{
            for(n = target->buckets[index]; n; n = _n) {{
              _n = n->next;
              {_destroy};
              {self.memory.free("n")};
            }}
          }}
          {self.memory.free("target->buckets")};
        }}
      """

    with self.method(None, "resize", {"target": inout(self), "new_size": std.size_t}, hidden=True, visibility="internal") as f:
      f.code = f"""
        size_t index, bucket, new_capacity;
        {self._bucket_p} buckets;
        {self.node}* n;
        {self.node}* _n;
        assert(target);
        new_capacity = _autoc_ceil_power2((size_t)(new_size/{self.capacity_threshold})); /* predict new capacity after size changing respecting the desired capacity threshold */
        if(new_capacity < 8) new_capacity = 8; /* enforce minimum viable capacity */
        if(new_capacity != target->capacity) {{
          buckets = {self.memory.allocate(self._node_p, "new_capacity", zero=True)}; assert(buckets);
          for(index = 0; index < target->capacity; ++index) {{
            for(n = target->buckets[index]; n; n = _n) {{
              _n = n->next;
              bucket = {self.element.hash_lookup_hash(node_element)} & (new_capacity-1); /* rehash the node into the new bucket array */
              n->next = buckets[bucket];
              buckets[bucket] = n;
            }}
          }}
          {self.memory.free("target->buckets")};
          target->buckets = buckets;
          target->capacity = new_capacity;
        }}
      """

    with self.contains as f:
      f.code = f"""
        size_t bucket;
        {self.node}* n;
        assert(target);
        if(!target->buckets) return 0;
        bucket = {self.element.hash_lookup_hash(f.element)} & (target->capacity-1);
        for(n = target->buckets[bucket]; n; n = n->next) {{
          if({self.element.hash_lookup_equal(node_element, f.element)}) return 1;
        }}
        return 0;
      """

    with self.put as f:
      f.code = f"""
        size_t bucket;
        {self.node}* n;
        assert(target);
        if({self.contains(f.target, f.element)}) return 0;
        {self.resize(f.target, "target->size+1")};
        bucket = {self.element.hash_lookup_hash(f.element)} & (target->capacity-1);
        n = {self.memory.allocate(self.node)}; assert(n);
        {self.element.copy(node_element, f.element)};
        n->next = target->buckets[bucket];
        target->buckets[bucket] = n;
        ++target->size;
        return 1;
      """

    with self.remove as f:
      _destroy = self.element.destroy(self.element.variable("n->element")) if self.element.destructible else str()
      f.code = f"""
        size_t bucket;
        {self.node}* n;
        {self.node}** p;
        assert(target);
        if(!target->buckets) return 0;
        bucket = {self.element.hash_lookup_hash(f.element)} & (target->capacity-1);
        for(p = &target->buckets[bucket]; *p; p = &(*p)->next) {{
          if({self.element.hash_lookup_equal(self.element.variable("(*p)->element"), f.element)}) {{
            n = *p;
            *p = n->next;
            {_destroy};
            {self.memory.free("n")};
            --target->size;
            return 1;
          }}
        }}
        return 0;
      """

    with self.method(self.element.view_type, ("find", "view"), {"target": self, "element": self.element}) as f:
      f.code = f"""
        size_t bucket;
        {self.node}* n;
        assert(target);
        if(!target->buckets) return ({self.element.view_type})0;
        bucket = {self.element.hash_lookup_hash(f.element)} & (target->capacity-1);
        for(n = target->buckets[bucket]; n; n = n->next) {{
          if({self.element.hash_lookup_equal(node_element, f.element)}) return {node_element.bind(f.result)};
        }}
        return ({self.element.view_type})0;
      """

    with self.copy as f:
      f.code = f"""
        size_t index, bucket;
        {self.node}* source_n;
        {self.node}* n;
        assert(target);
        assert(source);
        {self.create_size(f.target, "source->size")};
        for(index = 0; index < source->capacity; ++index) {{
          for(source_n = source->buckets[index]; source_n; source_n = source_n->next) {{
            bucket = {self.element.hash_lookup_hash(source_element)} & (target->capacity-1); /* direct planting in order to prevent from triggering the subsequent resizings */
            n = {self.memory.allocate(self.node)}; assert(n);
            {self.element.copy(target_element, source_element)};
            n->next = target->buckets[bucket];
            target->buckets[bucket] = n;
            ++target->size;
          }}
        }}
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        target->buckets = source->buckets;
        target->capacity = source->capacity;
        target->size = source->size;
        source->buckets = NULL;
        source->capacity = source->size = 0;
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
    stream.append(f"""
      /** @internal */
      typedef struct {self.node} {self.node};
      /** @internal */
      struct {self.node} {{
        {self.element} element;
        struct {self.node}* next;
      }};
    """)
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self._bucket_p} buckets; /**< @private */
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
          {std.size_t} bucket; /**< @private */
          {self.iterable.node}* node; /**< @private */
        }} {self.name};
      """)

  def __setup__(self):
    super().__setup__()

    node_element = self.element.variable("target->node->element")

    with self.method(None, "next", {"target": inout(self)}, hidden=True, visibility="internal") as f:
      f.code = f"""
        assert(target);
        while(!target->node && target->bucket < target->iterable->capacity) {{
          target->node = target->iterable->buckets[target->bucket];
          ++target->bucket;
        }}
      """

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(iterable);
        result.iterable = iterable;
        result.bucket = 0;
        result.node = NULL;
        {self.next("&result")};
        return {result};
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return !target->node;
      """

    with self.front as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, node_element)};
        return {result};
      """

    with self.front_view as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {node_element.bind(self.iterable.element.view_type)};
      """

    with self.move_front as f:
      f.code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        target->node = target->node->next;
        {self.next(f.target)};
      """
