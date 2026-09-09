from autoc.chained_hash_set import Set
from autoc.map import Map
from autoc.hash_map import _Entry
from autoc.range import Forward
from autoc.core import _StructRenderer
from autoc.collection import Range as _Range
from autoc.core import Indirection, Callable


#
class Map(_StructRenderer, Map):

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
    return False

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
    n = Indirection(set.node).variable("n")
    node_entry = entry.variable("n->element")
    node_index = entry.index.variable("n->element.index")

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

    with self.indexed as f:
      f.code = f"""
        size_t bucket;
        {n.definition};
        assert(target);
        if(!target->set.buckets) return 0;
        bucket = {self.index.hash(f.index)} & (target->set.capacity-1);
        for(n = target->set.buckets[bucket]; n; n = n->next) {{
          if({self.index.equal(node_index, f.index)}) return 1;
        }}
        return 0;
      """

    with self.view as f:
      f.code = f"""
        size_t bucket;
        {n.definition};
        assert(target);
        if(!target->set.buckets) return ({self.element.view_type})0;
        bucket = {self.index.hash(f.index)} & (target->set.capacity-1);
        for(n = target->set.buckets[bucket]; n; n = n->next) {{
          if({self.index.equal(node_index, f.index)}) return {entry.element_view(node_entry).bind(self.element.view_type)};
        }}
        return ({self.element.view_type})0;
      """

    with self.get as f:
      result = f.result.variable("result")
      f.code = f"""
        size_t bucket;
        {n.definition};
        {result.definition};
        assert(target);
        if(!target->set.buckets) abort();
        bucket = {self.index.hash(f.index)} & (target->set.capacity-1);
        for(n = target->set.buckets[bucket]; n; n = n->next) {{
          if({self.index.equal(node_index, f.index)}) break;
        }}
        if(!n) abort();
        {self.element.copy(result, entry.element_view(node_entry))};
        return {result};
      """

    with self.set as f:
      f.code = f"""
        size_t bucket;
        {n.definition};
        assert(target);
        bucket = {self.index.hash(f.index)} & (target->set.capacity-1);
        for(n = (target->set.buckets ? target->set.buckets[bucket] : ({n.type})0); n; n = n->next) {{
          if({self.index.equal(node_index, f.index)}) break;
        }}
        if(n) {{
          {entry.replace_element(node_entry, f.element)}; /* an entry with the specified index already exists - replace its element's contents in-place */
        }} else {{
          {self._set.resize(_target, "target->set.size+1")};
          bucket = {self.index.hash(f.index)} & (target->set.capacity-1); /* the capacity might have changed - recompute the bucket */
          {n} = {self.memory.allocate(set.node)}; assert(n);
          {entry.emplace_index(node_entry, f.index)};
          {entry.emplace_element(node_entry, f.element)};
          n->next = target->set.buckets[bucket];
          target->set.buckets[bucket] = n;
          ++target->set.size;
        }}
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

    with self.method(self.index, ("index", "front"), {"target": self}, constraint=lambda: self.index.copyable) as f:
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
