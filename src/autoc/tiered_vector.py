import autoc.std as std
from autoc.map import Map
from autoc.range import DirectAccess
from autoc.sequence import Sequence
from autoc.collection import _Range
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

  brief = "Append-optimized direct access sequence container"
  
  def __init__(self, name, element, chunk_shift=16, **kws):
    # memset is needed to zero-initialize the elements of the types which are
    # zero initializable but not default constructible
    super().__init__(name, element, std.size_t, dependencies=(std.string_h,), **kws)
    self.chunk_shift = int(chunk_shift)
    self.chunk_mask = (1 << self.chunk_shift) - 1
    self._chunk_p = Indirection(self.element)
    self._chunk_pp = Indirection(self._chunk_p)
    self.range = Range(self)

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the element type (@ref {self.element}) to be *Copyable*.
      Supports two way element traversal via the corresponding @ref {self.range} iterator
      as well as subranging with direct indexed access to the subrange's elements.

      Implemented as the fixed size chunks of elements addressed through the chunk table -
      the append is allocation-only with the stable element addresses.
      No direct C++ equivalent, but close to [std::deque<>](https://cppreference.com/cpp/container/deque).
    """

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

    with self.method(None, "extend", {"target": inout(self)}, hidden=True, visibility="internal", brief="Extend chunk table if needed (internal)") as f:
      f.code = f"""
        size_t index;
        {self._chunk_pp} chunks;
        assert(target);
        if(target->size == (target->chunk_count << {self.chunk_shift})) {{
          if(target->chunk_count == target->chunk_capacity) {{
            chunks = {self.memory.allocate(self._chunk_p, "(target->chunk_capacity ? target->chunk_capacity*2 : 8)")};
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

    with self.method(None, "push", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable, brief="Add element to back",
      description="""
        Appends the element in amortized O(1): the element lands in the last chunk and a fresh
        chunk of the fixed tier capacity is allocated when the current one fills up. Existing
        element addresses stay valid since the chunks never move.

        @param[in,out] target the vector to add to
        @param[in] element the element to add to the back
      """) as f:
      f.code = f"""
        assert(target);
        {self.extend(f.target)};
        {self.element.copy(self.element.variable(f"target->chunks[target->size >> {self.chunk_shift}][target->size & {self.chunk_mask}]"), f.element)};
        ++target->size;
      """

    with self.method(self.element, "pop", {"target": inout(self)}, constraint=lambda: self.element.moveable, brief="Remove and return element from back",
      description="""
        Moves the last element out in O(1). The chunk that became empty is not released -
        it is reused by the subsequent push operations.

        @param[in,out] target the vector to remove from - must not be empty
        @return the removed back element
      """) as f:
      result = f.result.variable("result")
      f.code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        --target->size;
        {self.element.move(result, self.element.variable(f"target->chunks[target->size >> {self.chunk_shift}][target->size & {self.chunk_mask}]"))};
        return {result};
      """

    # Resize grows the vector by extending the chunk table and default-initializing the
    # new elements in place - no element migration is ever needed since the chunks are
    # stable. Shrinking destroys the removed tail and releases the chunks which became
    # fully unused; the chunk table itself is not reallocated down
    resize_slot = lambda index: f"target->chunks[{index} >> {self.chunk_shift}][{index} & {self.chunk_mask}]"
    resize_destroy_i = str(self.element.destroy(self.element.variable(resize_slot("index")))) + ";" if self.element.destructible else str()
    if self.element.default_constructible:
      resize_create_i = str(self.element.create(self.element.variable(resize_slot("target->size")))) + ";"
    else:
      resize_create_i = f"memset(&({resize_slot('target->size')}), 0, sizeof({self.element}));"

    with self.method(None, "resize", {"target": inout(self), "size": self.index}, constraint=lambda: self.element.default_constructible or self.element.zero_initializable, brief="Resize the vector to the given number of elements",
      description="""
        Changes the number of elements: growing default-initializes the new elements in place
        extending the chunk table - no element migration is ever needed since the chunks are
        stable, so existing element addresses remain valid. Shrinking destroys the removed tail
        and releases the chunks which became fully unused; the chunk table itself is not
        reallocated down.

        @param[in,out] target the vector to resize
        @param[in] size the new number of elements - the tail is destroyed when shrinking and default-initialized when growing
      """) as f:
      f.code = f"""
        size_t index;
        size_t needed;
        assert(target);
        for(index = target->size; index < {f.size}; ++index) {{
          {self.extend(f.target)};
          {resize_create_i}
          ++target->size;
        }}
        if({f.size} < target->size) {{
          for(index = {f.size}; index < target->size; ++index) {{
            {resize_destroy_i}
          }}
          needed = ({f.size} + {self.chunk_mask}) >> {self.chunk_shift};
          for(index = needed; index < target->chunk_count; ++index) {{
            {self.memory.free("target->chunks[index]")};
          }}
          target->chunk_count = needed;
        }}
        target->size = {f.size};
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

    with self.method(None, ("create", "size"), {"target": out(self), "size": self.index}, constraint=lambda: self.element.default_constructible or self.element.zero_initializable, brief="Create the vector with room for the given number of default-constructed elements",
      description="""
        Creates the vector holding the given number of default-initialized elements laid out
        over the fixed capacity chunks. Zero-initializable elements are initialized by the
        zeroed chunk allocations alone; otherwise the elements are default constructed one by one.

        @param[out] target the vector to construct
        @param[in] size the number of default-initialized elements to provide room for
      """) as f:
      if self.element.zero_initializable:
        # The chunked zeroed allocation is the default initialization - no per element operations
        f.code = f"""
          size_t index, needed;
          assert(target);
          if({f.size} > 0) {{
            needed = ({f.size} + {self.chunk_mask}) >> {self.chunk_shift};
            target->chunks = {self.memory.allocate(self._chunk_p, "needed")}; assert(target->chunks);
            target->chunk_capacity = needed;
            for(index = 0; index < needed; ++index) {{
              target->chunks[index] = {self.memory.allocate(self.element, f"{1 << self.chunk_shift}", zero=True)};
            }}
            target->chunk_count = needed;
            target->size = {f.size};
          }} else {{
            {self.create(f.target)};
          }}
        """
      else:
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

    if self.comparable:
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

    # The sort cluster mirrors the vector one - the quicksort with the median-of-three pivot
    # and the insertion sort for the small ranges - with the element access redirected
    # through the chunk table. It is defined for the orderable, copyable and swappable
    # element types: the exchanges require the swappability while the pivot is copied out
    sort_constraint = lambda: self.element.orderable and self.element.copyable and self.element.swappable
    slot = lambda index: f"target->chunks[{index} >> {self.chunk_shift}][{index} & {self.chunk_mask}]"
    element_i = self.element.variable(slot("i"))
    element_j = self.element.variable(slot("j"))
    element_lo = self.element.variable(slot("lo"))
    element_mid = self.element.variable(slot("mid"))
    element_hi = self.element.variable(slot("hi"))
    element_prev = self.element.variable(slot("j-1"))
    pivot = self.element.variable("pivot")

    with self.method(None, ("sort", "insertion"), {"target": inout(self), "lo": self.index, "hi": self.index}, hidden=True, visibility="internal", constraint=sort_constraint, brief="Insertion sort the inclusive [lo, hi] range (internal)") as f:
      f.code = lambda f=f: f"""
        size_t i, j;
        assert(target);
        for(i = {f.lo} + 1; i <= {f.hi}; ++i) {{
          for(j = i; j > {f.lo} && {self.element.compare(element_prev, element_j)} > 0; --j) {{
            {self.element.swap(element_prev, element_j)};
          }}
        }}
      """

    with self.method(None, ("sort", "range"), {"target": inout(self), "lo": self.index, "hi": self.index}, hidden=True, visibility="internal", constraint=sort_constraint, brief="Quicksort the inclusive [lo, hi] range (internal)") as f:
      f.code = lambda f=f: f"""
        size_t i, j, mid;
        {pivot.definition};
        assert(target);
        while({f.lo} < {f.hi}) {{
          if({f.hi} - {f.lo} < 16) {{ /* small ranges are insertion sorted */
            {self.sort_insertion(f.target, f.lo, f.hi)};
            return;
          }}
          mid = {f.lo} + ({f.hi} - {f.lo})/2;
          /* median of three orders the lo, mid and hi elements protecting against the sorted inputs */
          if({self.element.compare(element_mid, element_lo)} < 0) {self.element.swap(element_mid, element_lo)};
          if({self.element.compare(element_hi, element_mid)} < 0) {{
            {self.element.swap(element_hi, element_mid)};
            if({self.element.compare(element_mid, element_lo)} < 0) {self.element.swap(element_mid, element_lo)};
          }}
          {self.element.copy(pivot, element_mid)};
          i = {f.lo};
          j = {f.hi};
          while(i <= j) {{
            while({self.element.compare(element_i, pivot)} < 0) ++i;
            while({self.element.compare(element_j, pivot)} > 0) --j;
            if(i >= j) break;
            {self.element.swap(element_i, element_j)};
            ++i;
            --j;
          }}
          {str(self.element.destroy(pivot)) + ";" if self.element.destructible else str()}
          /* recursing into the smaller part and iterating over the larger one bounds the recursion depth */
          if(j - {f.lo} < {f.hi} - i) {{
            {self.sort_range(f.target, f.lo, "j")};
            {f.lo} = i;
          }} else {{
            {self.sort_range(f.target, "i", f.hi)};
            {f.hi} = j;
          }}
        }}
      """

    with self.method(None, "sort", {"target": inout(self)}, constraint=sort_constraint, brief="Sort elements in ascending order",
      description="""
        Sorts the elements in ascending order with a quicksort variant: small ranges are
        insertion sorted, the pivot is the median of three which protects against the sorted
        inputs, and the recursion always descends into the smaller part to bound the depth.
        The sort is not stable and needs the element to be Orderable, Copyable and Swappable.
        The elements are addressed through their chunks so the sort stays independent of the
        chunk boundaries.

        @param[in,out] target the vector to sort
      """) as f:
      f.code = lambda f=f: f"""
        assert(target);
        if(target->size > 1) {self.sort_range(f.target, 0, "target->size-1")};
      """

    # Reversal is a pure exchange loop so it requires nothing but the element swappability
    with self.method(None, "reverse", {"target": inout(self)}, constraint=lambda: self.element.swappable, brief="Reverse the order of elements",
      description="""
        Reverses the element order in place by exchanging the mirrored element pairs.
        It needs nothing but the element swappability - no copies or destructions take place.

        @param[in,out] target the vector to reverse
      """) as f:
      f.code = lambda: f"""
        size_t i;
        assert(target);
        for(i = 0; i < target->size/2; ++i) {self.element.swap(self.element.variable(slot("i")), self.element.variable(slot("target->size-1-i")))}; 
      """

    with self.method("int", ("is", "sorted"), {"target": self}, constraint=lambda: self.element.orderable, brief="Check if elements are sorted in ascending order",
      description="""
        Walks the vector once returning non-zero when every element is not less than its
        predecessor. An empty or single element vector is considered sorted.

        @param[in] target the vector to check
        @return non-zero if the elements are sorted in ascending order
      """) as f:
      f.code = lambda: f"""
        size_t index;
        assert(target);
        for(index = 1; index < target->size; ++index) {{
          if({self.element.compare(self.element.variable(slot("index")), self.element.variable(slot("index-1")))} < 0) return 0;
        }}
        return 1;
      """

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._chunk_pp} chunks; /**< @private */
        {std.size_t} chunk_count; /**< @private */
        {std.size_t} chunk_capacity; /**< @private */
        {std.size_t} size; /**< @private */
      }};
    """)


#
class Range(_Range, DirectAccess):

  brief = "Direct access range over the tiered vector elements"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {Indirection(self.iterable, constant=True)} iterable; /**< @private */
        {std.size_t} front, back; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create the range spanning the whole tiered vector",
      description="""
        Creates the range over the chunked element storage. The range must not outlive
        the vector and the vector must not be resized while the range is traversed.

        @param[in] iterable the tiered vector to span
        @return the range covering the whole vector
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.iterable = iterable;
        result.front = 0;
        result.back = iterable->size;
        return {result};
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->front >= target->back;
      """

    with self.front as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->front")};
      """

    with self.front_view as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->front")};
      """

    with self.move_front as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        ++target->front;
      """

    with self.back as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.get("target->iterable", "target->back-1")};
      """

    with self.back_view as f:
      f.inline_code = lambda: f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {self.iterable.view("target->iterable", "target->back-1")};
      """

    with self.move_back as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        --target->back;
      """

    with self.get as f:
      f.inline_code = lambda: f"""
      assert(target);
      return {self.iterable.get("target->iterable", "target->front + index")};
    """

    with self.view as f:
      f.inline_code = lambda: f"""
        assert(target);
        return {self.iterable.view("target->iterable", "target->front + index")};
      """

    with self.size as f:
      f.inline_code = f"""
        assert(target);
        assert(target->back >= target->front);
        return target->back - target->front;
      """
