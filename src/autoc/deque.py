import autoc.std as std
from autoc.sequence import Sequence
from autoc.range import Bidirectional
from autoc.collection import _Range
from autoc.core import inout, _type, Callable, _StructRenderer


#
class Deque(_StructRenderer, Sequence):

  brief = "Ordered sequence with element insertion and removal at both ends"
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self.node = _type(self._decorate_component("node"))
    self.range = Range(self)

  @property
  def orderable(self):
    return False # TODO

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the element type (@ref {self.element}) to be *Copyable*.
      Supports two way element traversal via the corresponding @ref {self.range} iterator.

      Implemented as the doubly linked list.
      The closest C++ equivalent is [std::list<>](https://cppreference.com/cpp/container/list).
    """

    node_element = self.element.variable("node->element")
    front_element = self.element.variable("target->front->element")
    back_element = self.element.variable("target->back->element")
    target_element = self.element.variable("target_node->element")
    source_element = self.element.variable("source_node->element")

    with self.size as f:
      f.inline_code = f"""
        assert(target);
        return target->size;
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        assert((target->size == 0) == (target->front == NULL && target->back == NULL));
        return target->size == 0;
      """

    with self.create as f:
      f.inline_code = f"""
        assert(target);
        target->front = target->back = NULL;
        target->size = 0;
      """

    with self.destroy as f:
      f.code = f"""
        {self.node}* node;
        assert(target);
        node = target->front;
        while(node) {{
          {self.node}* _node;
           _node = node;
          {self.element.destroy(node_element) if self.element.destructible else str()};
          node = node->next;
          {self.memory.free("_node")};
        }}
      """

    with self.copy as f:
      f.code = f"""
        size_t size;
        {self.node}* target_node;
        {self.node}* source_node;
        assert(target);
        assert(source);
        target->front = target->back = NULL;
        target->size = size = {self.size("source")};
        while(size--) {{
          {self.node}* node;
          node = {self.memory.allocate(self.node)}; assert(node);
          node->prev = target->back;
          node->next = NULL;
          if(target->back) target->back->next = node; else target->front = node;
          target->back = node;
        }}
        target_node = target->front;
        source_node = source->front;
        while(target_node && source_node) {{
          {self.element.copy(target_element, source_element)};
          target_node = target_node->next;
          source_node = source_node->next;
        }}
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        target->front = source->front;
        target->back = source->back;
        target->size = source->size;
        {self.create(f.source)};
      """

    with self.method(None, ("push", "front"), {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable, brief="Add element to front",
      description="""
        Inserts the element at the front in O(1) by allocating a new node and linking it
        before the current front. Other elements are untouched so their addresses stay valid.

        @param[in,out] target the deque to add to
        @param[in] element the element to add to the front
      """) as f:
      f.code = f"""
        {self.node}* node;
        assert(target);
        node = {self.memory.allocate(self.node)}; assert(node);
        {self.element.copy(node_element, f.element)};
        node->prev = NULL;
        node->next = target->front;
        if(target->front) target->front->prev = node; else target->back = node;
        target->front = node;
        ++target->size;
      """

    with self.method(self.element, ("pop", "front"), {"target": inout(self)}, constraint=lambda: self.element.moveable, brief="Remove and return element from front",
      description="""
        Moves the front element out and releases its node in O(1). The returned element
        is a moved copy so the caller owns it.

        @param[in,out] target the deque to remove from - must not be empty
        @return the removed front element
      """) as f:
      result = f.result.variable("result")
      f.code = f"""
        {self.node}* node;
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        node = target->front;
        {self.element.move(result, node_element)};
        target->front = node->next;
        if(target->front) target->front->prev = NULL; else target->back = NULL;
        {self.memory.free("node")};
        --target->size;
        return {result};
      """

    with self.method(None, ("push", "back"), {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable, brief="Add element to back",
      description="""
        Appends the element at the back in O(1) by allocating a new node and linking it
        after the current back. Other elements are untouched so their addresses stay valid.

        @param[in,out] target the deque to add to
        @param[in] element the element to add to the back
      """) as f:
      f.code = f"""
        {self.node}* node;
        assert(target);
        node = {self.memory.allocate(self.node)}; assert(node);
        {self.element.copy(node_element, f.element)};
        node->next = NULL;
        node->prev = target->back;
        if(target->back) target->back->next = node; else target->front = node;
        target->back = node;
        ++target->size;
      """

    with self.method(self.element, ("pop", "back"), {"target": inout(self)}, constraint=lambda: self.element.moveable, brief="Remove and return element from back",
      description="""
        Moves the back element out and releases its node in O(1). The returned element
        is a moved copy so the caller owns it.

        @param[in,out] target the deque to remove from - must not be empty
        @return the removed back element
      """) as f:
      result = f.result.variable("result")
      f.code = f"""
        {self.node}* node;
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        node = target->back;
        {self.element.move(result, node_element)};
        target->back = node->prev;
        if(target->back) target->back->next = NULL; else target->front = NULL;
        {self.memory.free("node")};
        --target->size;
        return {result};
      """

    with self.method(self.element, "front", {"target": self}, constraint=lambda: self.element.copyable, brief="Get front element",
      description="""
        Returns a copy of the first element in O(1) without modifying the deque.

        @param[in] target the deque to read - must not be empty
        @return the element at the front
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, front_element)};
        return {result};
      """

    with self.method(self.element.view_type, ("front", "view"), {"target": self}, brief="Get view of front element",
      description="""
        Returns a pointer to the first element without copying it in O(1). The view is valid
        while that element is held by the deque - removing it invalidates the view.

        @param[in] target the deque to read - must not be empty
        @return a constant view of the element at the front, valid while the element is held by the deque
      """) as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {front_element.bind(f.result)};
      """

    with self.method(self.element, "back", {"target": self}, constraint=lambda: self.element.copyable, brief="Get back element",
      description="""
        Returns a copy of the last element in O(1) without modifying the deque.

        @param[in] target the deque to read - must not be empty
        @return the element at the back
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, back_element)};
        return {result};
      """

    with self.method(self.element.view_type, ("back", "view"), {"target": self}, brief="Get view of back element",
      description="""
        Returns a pointer to the last element without copying it in O(1). The view is valid
        while that element is held by the deque - removing it invalidates the view.

        @param[in] target the deque to read - must not be empty
        @return a constant view of the element at the back, valid while the element is held by the deque
      """) as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {back_element.bind(f.result)};
      """

    lt = self.element.variable("lt->element")
    rt = self.element.variable("rt->element")

    with self.equal as f:
      f.code = f"""
        assert(left);
        assert(right);
        if(left->size == right->size) {{
          {self.node}* lt;
          {self.node}* rt;
          lt = left->front;
          rt = right->front;
          while(lt && rt) {{
            if(!{self.element.equal(lt, rt)}) return 0;
            lt = lt->next;
            rt = rt->next;
          }}
        }} else return 0;
        return 1;
      """


  def _render_struct(self, stream, header):
    stream.append(f"""
      /** @private */
      typedef struct {self.node} {self.node};
      /** @private */
      struct {self.node} {{
        {self.element} element;
        {self.node}* next;
        {self.node}* prev;
      }};
    """)
    super()._render_struct(stream, header)
    stream.append(f"""
      typedef struct {{
        {self.node}* front; /**< @private */
        {self.node}* back; /**< @private */
        {std.size_t} size; /**< @private */
      }} {self.name};
    """)


#
class Range(_Range, Bidirectional):

  brief = "Bidirectional range over the deque elements"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      typedef struct {{
        {self.iterable.node}* front; /**< @private */
        {self.iterable.node}* back; /**< @private */
      }} {self.name};
    """)

  def __setup__(self):
    super().__setup__()

    with self.method(Callable.Parameter(self), "new", {"iterable" : self.iterable}, brief="Create the range spanning the whole deque",
      description="""
        Creates the range over the node chain traversable in both directions from front
        to back and back. The range must not outlive the deque and the deque must not be
        modified while the range is traversed.

        @param[in] iterable the deque to span
        @return the range covering the whole deque
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.front = iterable->front;
        result.back = iterable->back;
        return {result};
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return !target->front || !target->back || target->front == target->back->next || target->back == target->front->prev;
      """

    front_element = self.iterable.element.variable("target->front->element")
    back_element = self.iterable.element.variable("target->back->element")

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
        return {front_element.bind(f.result)};
      """

    with self.move_front as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        target->front = target->front->next;
      """

    with self.back as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, back_element)};
        return {result};
      """

    with self.back_view as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return {back_element.bind(f.result)};
      """

    with self.move_back as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        target->back = target->back->prev;
      """
