import autoc.std as std
from autoc.map import Map
from autoc.range import Forward
from autoc.sequence import Sequence
from autoc.collection import Range as _Range
from autoc.core import inout, out, Indirection, _StructRenderer, Callable


#
class TieredVector(_StructRenderer, Map, Sequence):
  # The append-optimized direct-access container: the elements are stored in fixed size
  # chunks addressed through the chunk table which makes the growth allocation-only
  # (no element copying, stable element addresses) while keeping the O(1) indexed access
  # through the power of two chunk size shift and mask. The destruction of the destructor-less
  # element types elides the element loop entirely leaving only the chunk releases
  # which makes the teardown of the huge transient buffers O(chunks) rather than O(elements)

  # TODO direct access get/set/inset/remove etc

  def __init__(self, name, element, chunk_shift=16, **kws):
    super().__init__(name, element, std.size_t, **kws)
    self.chunk_shift = int(chunk_shift)
    self.chunk_mask = (1 << self.chunk_shift) - 1
    self._chunk_p = Indirection(self.element)
    self._chunk_pp = Indirection(self._chunk_p)
    self.range = Range(self)

  @property
  def orderable(self):
    return False # TODO

  def __setup__(self):
    super().__setup__()

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
        target->chunks = NULL;
        target->chunk_count = target->chunk_capacity = target->size = 0;
      """

    with self.indexed as f:
      f.inline_code = f"""
        assert(target);
        return {f.index} < target->size;
      """

    with self.method(None, "extend", {"target": inout(self)}, hidden=True, visibility="internal") as f:
      f.code = f"""
        size_t index;
        {self._chunk_pp} chunks;
        assert(target);
        if(target->size == (target->chunk_count << {self.chunk_shift})) {{
          if(target->chunk_count == target->chunk_capacity) {{
            chunks = {self.memory.allocate(self._chunk_p, "target->chunk_capacity ? target->chunk_capacity*2 : 8")};
            assert(chunks);
            for(index = 0; index < target->chunk_count; ++index) chunks[index] = target->chunks[index];
            {self.memory.free("target->chunks")};
            target->chunks = chunks;
            target->chunk_capacity = target->chunk_capacity ? target->chunk_capacity*2 : 8;
          }}
          target->chunks[target->chunk_count] = {self.memory.allocate(self.element, f"{1 << self.chunk_shift}")};
          assert(target->chunks[target->chunk_count]);
          ++target->chunk_count;
        }}
      """

    with self.destroy as f:
      if self.element.destructible:
        f.code = f"""
          size_t index;
          assert(target);
          if(target->chunks) {{
            for(index = 0; index < target->size; ++index) {{
              {self.element.destroy(self.element.variable("target->chunks[index >> "f"{self.chunk_shift}][index & {self.chunk_mask}]"))};
            }}
            for(index = 0; index < target->chunk_count; ++index) {{
              {self.memory.free("target->chunks[index]")};
            }}
            {self.memory.free("target->chunks")};
          }}
        """
      else:
        f.code = f"""
          size_t index;
          assert(target);
          if(target->chunks) {{
            for(index = 0; index < target->chunk_count; ++index) {{
              {self.memory.free("target->chunks[index]")};
            }}
            {self.memory.free("target->chunks")};
          }}
        """

    with self.method(None, "push", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable) as f:
      f.code = f"""
        assert(target);
        {self.extend(f.target)};
        {self.element.copy(self.element.variable(f"target->chunks[target->size >> {self.chunk_shift}][target->size & {self.chunk_mask}]"), f.element)};
        ++target->size;
      """

    with self.method(self.element, "pop", {"target": inout(self)}, constraint=lambda: self.element.moveable) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        --target->size;
        {self.element.move(result, self.element.variable(f"target->chunks[target->size >> {self.chunk_shift}][target->size & {self.chunk_mask}]"))};
        return {result};
      """

    with self.get as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {self.element.copy(result, self.element.variable(f"target->chunks[{f.index} >> {self.chunk_shift}][{f.index} & {self.chunk_mask}]"))};
        return {result};
      """

    # FIXME explicit casting here and there in the respective Range type is a kind of hack to deal with double pointer types
    # Normally Pointer type should be responsible for handling the per-indirection constness flags
    with self.view as f:
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        return {self.element.variable(f"target->chunks[{f.index} >> {self.chunk_shift}][{f.index} & {self.chunk_mask}]").bind(f.result)};
      """

    destroy_i = str(self.element.destroy(self.element.variable(f"target->chunks[index >> {self.chunk_shift}][index & {self.chunk_mask}]"))) + ";" if self.element.destructible else str()

    with self.set as f:
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {destroy_i}
        {self.element.copy(self.element.variable(f"target->chunks[{f.index} >> {self.chunk_shift}][{f.index} & {self.chunk_mask}]"), f.element)};
      """

    with self.method(None, ("create", "size"), {"target": out(self), "size": self.index}, constraint=lambda: self.element.default_constructible) as f:
      f.code = f"""
        size_t index;
        assert(target);
        {self.create(f.target)};
        for(index = 0; index < {f.size}; ++index) {{
          {self.extend(f.target)};
          {self.element.create(self.element.variable(f"target->chunks[target->size >> {self.chunk_shift}][target->size & {self.chunk_mask}]"))};
          ++target->size;
        }}
      """

    with self.copy as f:
      f.code = f"""
        size_t index;
        assert(target);
        assert(source);
        {self.create(f.target)};
        for(index = 0; index < source->size; ++index) {{
          {self.extend(f.target)};
          {self.element.copy(self.element.variable(f"target->chunks[target->size >> {self.chunk_shift}][target->size & {self.chunk_mask}]"), self.element.variable(f"source->chunks[index >> {self.chunk_shift}][index & {self.chunk_mask}]"))};
          ++target->size;
        }}
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        target->chunks = source->chunks;
        target->chunk_count = source->chunk_count;
        target->chunk_capacity = source->chunk_capacity;
        target->size = source->size;
        {self.create(f.source)};
      """

    with self.equal as f:
      f.code = f"""
        size_t index;
        assert(left);
        assert(right);
        if(left->size == right->size) {{
          for(index = 0; index < left->size; ++index) {{
            if(!{self.element.equal(self.element.variable(f"left->chunks[index >> {self.chunk_shift}][index & {self.chunk_mask}]"), self.element.variable(f"right->chunks[index >> {self.chunk_shift}][index & {self.chunk_mask}]"))}) return 0;
          }}
          return 1;
        }} else return 0;
      """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self._chunk_pp} chunks; /**< @private */
      {std.size_t} chunk_count; /**< @private */
      {std.size_t} chunk_capacity; /**< @private */
      {std.size_t} size; /**< @private */
    }} {self.name};
    """)


#
class Range(_Range, Forward):

  # TODO direct access

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Indirection(self.iterable, constant=True)} iterable; /**< @private */
          {std.size_t} front; /**< @private */
        }} {self.name};
      """)

  def __setup__(self):
    super().__setup__()

    front_element = self.element.variable(f"target->iterable->chunks[target->front >> {self.iterable.chunk_shift}][target->front & {self.iterable.chunk_mask}]")

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        return {result};
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->front >= target->iterable->size;
      """

    with self.front as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, front_element)};
        return {result};
      """

    with self.front_view as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {front_element.bind(self.iterable.element.view_type)};
      """

    with self.move_front as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        ++target->front;
      """
