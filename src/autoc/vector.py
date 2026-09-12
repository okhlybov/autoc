import autoc.std as std
from autoc.map import Map
from autoc.sequence import Sequence
from autoc.range import DirectAccess
from autoc.collection import Range as _Range
from autoc.core import out, inout, Macro, Callable, Indirection, _StructRenderer


#
class Vector(_StructRenderer, Map, Sequence):

  def __init__(self, name, element, **kws):
    super().__init__(name, element, std.size_t, **kws)
    self.range = Range(self)

  @property
  def orderable(self):
    return False # TODO
  
  def __setup__(self):
    super().__setup__()
    
    left_i = self.element.variable("left->elements[index]")
    right_i = self.element.variable("right->elements[index]")
    source_i = self.element.variable("source->elements[index]")
    target_i = self.element.variable("target->elements[index]")

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return target->size == 0;
      """
    
    with self.indexed as f:
      f.inline_code = f"""
        assert(target);
        return index < target->size;
      """
    
    with self.size as f:
      f.inline_code = f"""
        assert(target);
        return target->size;
      """
    
    with self.method(None, "allocate", {"target": out(self), "capacity": self.index}, visibility="private") as f:
      f.code = f"""
        assert(target);
        if(capacity > 0) {{
          target->elements = {self.memory.allocate(self.element, f.capacity)}; assert(target->elements);
        }} else target->elements = NULL;
        target->size = capacity;
      """
    
    # TODO make use of zero initializable feature of primitives
    with self.method(None, ("create", "size"), {"target": out(self), "size": self.index}, constraint=lambda: self.element.default_constructible) as f:
      f.code = f"""
        assert(target);
        if(size > 0) {{
          {self.index} index;
          {self.allocate(*f.arguments)};
          for(index = 0; index < size; ++index) {self.element.create(target_i)};
        }} else {{
          target->elements = NULL;
          target->size = 0;
        }}
      """

    with self.get as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {self.element.copy(result, target_i)};
        return {result};
      """
    
    # FIXME explicit casting here and ithere in the respective Range type is a kind of hack to deal with double pointer types
    # Normally Pointer type should be responsible for handling the per-indirection constness flags
    
    with self.view as f:
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        return {target_i.bind(f.result)};
      """

    destroy_i = self.element.destroy(target_i) if self.element.destructible else str()
    
    with self.set as f:
      f.inline_code = f"""
        assert(target);
        assert({self.indexed(f.target, f.index)});
        {destroy_i};
        {self.element.copy(target_i, f.element)};
      """

    with self.create as f:
      f.inline_code = """
        assert(target);
        target->elements = NULL;
        target->size = 0;
      """
    
    with self.destroy as f:
      if self.element.destructible:
        f.code = f"""
          {self.index} index;
          assert(target);
          if(target->size > 0) {{
            for(index = 0; index < target->size; ++index) {self.element.destroy(target_i)};
            {self.memory.free("target->elements")};
          }}
        """
      else:
        f.inline_code = f"""
          assert(target);
          if(target->size > 0) {self.memory.free("target->elements")};
        """

    # FIXME should come from sequence    
    with self.equal as f:
      f.code = f"""
        assert(left);
        assert(right);
        if(left->size == right->size) {{
          {self.index} index;
          for(index = 0; index < left->size; ++index) {{
            if(!{self.element.equal(left_i, right_i)}) return 0;
          }}
          return 1;
        }} else return 0;
      """

    with self.copy as f:
      f.code = f"""
        {self.index} index;
        assert(target);
        assert(source);
        {self.allocate(f.target, "source->size")};
        for(index = 0; index < target->size; ++index) {self.element.copy(target_i, source_i)};
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        target->elements = source->elements;
        target->size = source->size;
        {self.create(f.source)};
      """

    # Sorting is defined only for the orderable element types as it is entirely built on top of the element comparison.
    # The algorithm is a quicksort with the median-of-three pivot and the insertion sort applied to the small ranges.
    # The swap based implementation leverages the element's swappability: swapping exchanges the representations of two
    # complete values so both sides remain valid afterwards - unlike move it requires no pristine state to be left behind.
    # The sort cluster exchanges the elements so it requires swappability in addition to orderability
    # while the pivot is still copied out so the copyability is required as well
    if self.element.orderable and self.element.copyable and self.element.swappable:
      element_i = self.element.variable("target->elements[i]")
      element_j = self.element.variable("target->elements[j]")
      element_lo = self.element.variable("target->elements[lo]")
      element_mid = self.element.variable("target->elements[mid]")
      element_hi = self.element.variable("target->elements[hi]")
      element_prev = self.element.variable("target->elements[j-1]")
      pivot = self.element.variable("pivot")
      destroy_pivot = f"{self.element.destroy(pivot)};" if self.element.destructible else str()

      with self.method(None, ("sort", "insertion"), {"target": inout(self), "lo": self.index, "hi": self.index}, hidden=True, visibility="internal") as f:
        f.code = f"""
          size_t i, j;
          assert(target);
          for(i = {f.lo} + 1; i <= {f.hi}; ++i) {{
            for(j = i; j > {f.lo} && {self.element.compare(element_prev, element_j)} > 0; --j) {{
              {self.element.swap(element_prev, element_j)};
            }}
          }}
        """

      with self.method(None, ("sort", "range"), {"target": inout(self), "lo": self.index, "hi": self.index}, hidden=True, visibility="internal") as f:
        f.code = f"""
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
            {destroy_pivot}
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

      with self.method(None, "sort", {"target": inout(self)}) as f:
        f.code = f"""
          assert(target);
          if(target->size > 1) {self.sort_range(f.target, 0, "target->size-1")};
        """

    # Reversal is a pure exchange loop so it requires nothing but the element swappability
    if self.element.swappable:
      with self.method(None, "reverse", {"target": inout(self)}) as f:
        f.code = f"""
          size_t i;
          assert(target);
          for(i = 0; i < target->size/2; ++i) {self.element.swap(self.element.variable("target->elements[i]"), self.element.variable("target->elements[target->size-1-i]"))};
        """

      with self.method("int", ("is", "sorted"), {"target": self}) as f:
        f.code = f"""
          size_t index;
          assert(target);
          for(index = 1; index < target->size; ++index) {{
            if({self.element.compare(self.element.variable("target->elements[index]"), self.element.variable("target->elements[index-1]"))} < 0) return 0;
          }}
          return 1;
        """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {Indirection(self.element)} elements; /**< @private */
      {self.index} size; /**< @private */
    }} {self.name};
    """)


#
class Range(_Range, DirectAccess):
  
  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"""
        typedef struct {{
          {Indirection(self.iterable, constant=True)} iterable; /**< @private */
          {self.iterable.index} front, back; /**< @private */
        }} {self.name};
      """)

  def _copy(self, result, parameters, **kws):
    return Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable" : self.iterable}) as f:
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