import autoc.core
import autoc.range
import autoc.composite
import autoc.std as std
from autoc.core import inout


class List(autoc.composite._StructRenderer, autoc.composite.Collection, autoc.core._NoTraits):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, **kws)
    self.node = autoc.core._type(f"{self.decorate(None, hidden=True)}n")
    
  def __setup__(self):
    super().__setup__()
    
    self.empty.code = f"""
      assert(target);
      assert((target->size == 0) == (target->front == NULL));
      return target->size == 0;
    """
    self._inline_policy(self.empty)
    
    self.create.code = f"""
      assert(target);
      target->front = NULL;
      target->size = 0;
    """
    self._inline_policy(self.create)
    
    self.destroy.code = f"""
      {self.node}* node;
      assert(target);
      node = target->front;
      while(node) {{
        {self.element.destroy(node_element) if self.element.destructible else str()};
        {self.memory.free("node")};
        node = node->next;
      }}
    """
    self._inline_policy(self.destroy)
    
    self.size = self.method(std.size_t, "size", {"target": self}, code=f"""
      assert(target);
      return target->size;
    """)
    self._inline_policy(self.size)
    
    front_element = self.element.variable("target->front->element")
    node_element = self.element.variable("node->element")
    target_element = self.element.variable("target_node->element")
    source_element = self.element.variable("source_node->element")
    result = self.element.variable("result")
    
    self.copy.code = f"""
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
    self._inline_policy(self.copy)

    self.push_front = self.method(None, ("push", "front"), {"target": inout(self), "element": self.element})
    self.push_front.code = f"""
      assert(target);
      {self.node}* node = {self.memory.allocate(self.node)}; assert(node);
      {self.element.copy(node_element, self.push_front.element)};
      node->next = target->front;
      target->front = node;
      ++target->size;
    """
    self._inline_policy(self.push_front)
      
    self.pop_front = self.method(self.element, ("pop", "front"), {"target": inout(self)})
    self.pop_front.code = f"""
      {self.node}* node;
      {result.definition};
      assert(target);
      assert(!{self.empty("target")});
      node = target->front;
      {self.element.copy(result, node_element)};
      {self.element.destroy(node_element) if self.element.destructible else str()};
      target->front = node->next;
      {self.memory.free("node")};
      --target->size;
      return {result};
    """
    self._inline_policy(self.pop_front)
    
    self.view_front = self.method(self.element_view, ("view", "front"), {"target": self})
    self.view_front.code = f"""
      assert(target);
      assert(!{self.empty("target")});
      return ({self.view_front.result})&{front_element};
    """
    self._inline_policy(self.view_front)
    
    lt = self.node.variable("lt->element")
    rt = self.node.variable("rt->element")
    self.equal.code = f"""
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
    self._inline_policy(self.equal)
    
    state = self.hasher.state_t.variable("state")
    self.hash.code = f"""
      size_t result;
      {self.node}* node;
      {state.definition};
      assert(target);
      {self.hasher.create("state")};
      node = target->front;
      while(node) {{
        {self.hasher.update("state", self.element.hash(node_element))};
        node = node->next;
      }}
      result = {self.hasher.hash(state)};
      {self.hasher.destroy(state)};
      return result;
    """
    self._inline_policy(self.hash)
    
    self.range = Range(self)
    self.references.add(self.range)
    
  @property
  def constructible(self):
    return True

  @property
  def destructible(self):
    return True
  
  @property
  def comparable(self):
    return self.element.comparable
  
  @property
  def hashable(self):
    return self.element.hashable
  
  @property
  def copyable(self):
    return self.element.copyable
  
  def _render_struct(self, stream):
    stream.append(f"""
      /** @private */
      typedef struct {self.node} {self.node};
      /** @private */
      struct {self.node} {{
        {self.element.variable("element").definition};
        {self.node}* next;
      }};
    """)
    if self.public:
      stream.append("/** @public */\n")
    if self.private:
      stream.append("/** @private */\n")
    stream.append(f"""typedef struct {{
      {self.node}* front; /**< @private */
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
          {self.iterable.node}* front;
        }} {self.name};
      """)

  def _copy(self, result, parameters, **kws):
    return autoc.core.Macro(result, parameters, lambda target, source: f"{target} = {source}", **kws)

  def __setup__(self):
    super().__setup__()
    
    self.new = self.method(self, "new", {"iterable" : inout(self.iterable)})

    self.new.linkage = "INLINE"
    self.new.code = f"""
      assert(iterable);
      return ({self}){{ iterable->front }};
    """

    self.empty.linkage = "INLINE"
    self.empty.code = f"""
      assert(target);
      return !target->front;
    """
    
    self.view_front.linkage = "INLINE"
    self.view_front.code = f"""
      assert(target);
      assert(!{self.empty("target")});
      return ({self.iterable.element_view})&target->front->element;
    """
    
    self.pop_front.linkage = "INLINE"
    self.pop_front.code = f"""
      assert(target);
      assert(!{self.empty("target")});
      target->front = target->front->next;
    """
    
    result = self.element.variable("result")
    front_element = self.element.variable("target->front->element")
    
    self.front.linkage = "INLINE"
    self.front.code = f"""
      {result.definition};
      assert(target);
      assert(!{self.empty("target")});
      {self.element.copy(result, front_element)};
      return result;
    """