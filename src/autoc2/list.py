import autoc2.std as std
from autoc2.hash import XorRot
from autoc2.range import Forward
from autoc2.collection import _Range
from autoc2.sequence import Sequence
from autoc2.composite import _StructRenderer
from autoc2.core import inout, _type, Callable


#
class List(_StructRenderer, Sequence):
  
  def __init__(self, *args, hasher=XorRot(), **kws):
    super().__init__(*args, hasher=hasher, **kws)
    self.node = _type(self._decorate_component("node"))
    self.range = Range(self)
    
  def __setup__(self):
    super().__setup__()

    #self.compare = None
    
    node_element = self.element.variable("node->element")
    front_element = self.element.variable("target->front->element")
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
        assert((target->size == 0) == (target->front == NULL));
        return target->size == 0;
      """
    
    with self.create as f:
      f.inline_code = f"""
        assert(target);
        target->front = NULL;
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
        target->front = NULL;
        target->size = size = {self.size("source")};
        while(size--) {{
          {self.node}* node;
          node = {self.memory.allocate(self.node)}; assert(node);
          node->next = target->front;
          target->front = node;
        }}
        target_node = target->front;
        source_node = source->front;
        while(target_node && source_node) {{
          {self.element.copy(target_element, source_element)};
          target_node = target_node->next;
          source_node = source_node->next;
        }}
      """

    with self.method(None, ("push", "front"), {"target": inout(self), "element": self.element}) as f:
      f.code = f"""
        {self.node}* node;
        assert(target);
        node = {self.memory.allocate(self.node)}; assert(node);
        {self.element.copy(node_element, f.element)};
        node->next = target->front;
        target->front = node;
        ++target->size;
      """
      
    with self.method(self.element, ("pop", "front"), {"target": inout(self)}) as f:
      result = f.result.variable("result")
      f.code = f"""
        {self.node}* node;
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        node = target->front;
        {self.element.copy(result, node_element)};
        {self.element.destroy(node_element) if self.element.destructible else str()};
        target->front = node->next;
        {self.memory.free("node")};
        --target->size;
        return {result};
      """
    
    with self.method(self.element, "front", {"target": self}) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, front_element)};
        return {result};
      """

    with self.method(self.element_view, ("front", "view"), {"target": self}) as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return ({f.result})&{front_element};
      """
    
    lt = self.node.variable("lt->element")
    rt = self.node.variable("rt->element")
    
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


  def _render_struct(self, stream):
    stream.append(f"""
      /** @internal */
      typedef struct {self.node} {self.node};
      /** @internal */
      struct {self.node} {{
        {self.element.variable("element").definition};
        {self.node}* next;
      }};
    """)
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self.node}* front; /**< @private */
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
          {self.iterable.node}* front; /**< @private */
        }} {self.name};
      """)

  def __setup__(self):
    super().__setup__()
    
    with self.method(Callable.Parameter(self), "new", {"iterable" : self.iterable}) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.front = iterable->front;
        return {result};
      """

    with self.empty as f:
      f.inline_code = f"""
        assert(target);
        return !target->front;
      """

    front_element = self.element.variable("target->front->element")
    
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
        return ({self.iterable.element_view})&target->front->element;
      """
    
    with self.move_front as f:
      f.inline_code = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        target->front = target->front->next;
      """
