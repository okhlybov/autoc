import autoc.core
import autoc.hash
import autoc.std as std
from autoc.core import inout
from autoc.range import Forward
from autoc.collection import _Range as CollectionRange
from autoc.sequence import Sequence
from autoc.composite import _StructRenderer


#
class List(_StructRenderer, Sequence):
  
  def __init__(self, *args, hasher=autoc.hash.XorShift(), **kws):
    super().__init__(*args, hasher=hasher, **kws)
    self.node = autoc.core._type(self._decorate_component("node"))
    self.range = Range(self)
    
  def __setup__(self):
    super().__setup__()
    
    with self.empty as f:
      f.inline = f"""
        assert(target);
        assert((target->size == 0) == (target->front == NULL));
        return target->size == 0;
      """
    
    with self.create as f:
      f.inline = f"""
        assert(target);
        target->front = NULL;
        target->size = 0;
      """
    
    with self.destroy as f:
      f.external = f"""
        {self.node}* node;
        assert(target);
        node = target->front;
        while(node) {{
          {self.node}* _node = node;
          {self.element.destroy(node_element) if self.element.destructible else str()};
          node = node->next;
          {self.memory.free("_node")};
        }}
      """
    
    with self.size as f:
      f.inline = f"""
        assert(target);
        return target->size;
      """
    
    front_element = self.element.variable("target->front->element")
    node_element = self.element.variable("node->element")
    target_element = self.element.variable("target_node->element")
    source_element = self.element.variable("source_node->element")
    result = self.element.variable("result")
    
    with self.copy as f:
      f.external = f"""
        size_t size;
        {self.node}* target_node;
        {self.node}* source_node;
        assert(target);
        assert(source);
        target->front = NULL;
        target->size = size = {self.size("source")};
        while(size--) {{
          {self.node}* node = {self.memory.allocate(self.node)}; assert(node);
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
      f.external = f"""
        assert(target);
        {self.node}* node = {self.memory.allocate(self.node)}; assert(node);
        {self.element.copy(node_element, f.element)};
        node->next = target->front;
        target->front = node;
        ++target->size;
      """
      
    with self.method(self.element, ("pop", "front"), {"target": inout(self)}) as f:
      f.external = f"""
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
      f.external = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, front_element)};
        return {result};
      """

    with self.method(self.element_view, ("front", "view"), {"target": self}) as f:
      f.external = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return ({f.result})&{front_element};
      """
    
    lt = self.node.variable("lt->element")
    rt = self.node.variable("rt->element")
    
    with self.equal as f:
      f.external = f"""
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
class Range(CollectionRange, Forward):
  
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
    
    with self.method(self, "new", {"iterable" : self.iterable}) as f:
      f.inline = f"""
        {self} result;
        assert(iterable);
        result.front = iterable->front;
        return result;
      """

    with self.empty as f:
      f.inline = f"""
        assert(target);
        return !target->front;
      """

    result = self.element.variable("result")
    front_element = self.element.variable("target->front->element")
    
    with self.front as f:
      f.inline = f"""
        {result.definition};
        assert(target);
        assert(!{self.empty(f.target)});
        {self.element.copy(result, front_element)};
        return result;
      """

    with self.front_view as f:
      f.inline = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        return ({self.iterable.element_view})&target->front->element;
      """
    
    self.move_front.linkage = "INLINE"
    with self.move_front as f:
      f.inline = f"""
        assert(target);
        assert(!{self.empty(f.target)});
        target->front = target->front->next;
      """
