import autoc.std as std
from autoc.random import Randomizer
from autoc.range import Forward
from autoc.set import Set
from autoc.collection import Range as _Range
from autoc.core import inout, _type, _StructRenderer, Indirection, Callable, Expression


#
class Set(_StructRenderer, Set):

  def __init__(self, *args, randomizer=Randomizer(), dependencies=(), **kws):
    super().__init__(*args, dependencies=(*dependencies, randomizer), **kws)
    self.node = _type(self._decorate_component("node"))
    self._node_p = Indirection(self.node)
    self.randomizer = randomizer
    self.range = Range(self)

  @property
  def orderable(self):
    return True

  @property
  def copyable(self):
    return self.element.copyable and self.element.comparable

  def __setup__(self):
    super().__setup__()

    node_element = self.element.variable("n->element")
    link_element = self.element.variable("(*link)->element")
    # Node pointer expressions bound to their C side counterparts
    node = Expression(self._node_p, "n")
    node_parent = Expression(self._node_p, "n->parent")
    node_left = Expression(self._node_p, "n->left")
    node_right = Expression(self._node_p, "n->right")

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
        target->root = NULL;
        target->size = 0;
      """

    with self.destroy as f:
      _destroy = self.element.destroy(node_element) if self.element.destructible else str()
      f.code = f"""
        {self.node}* n;
        {self.node}* p;
        assert(target);
        n = target->root;
        while(n) {{
          if(n->left) {{
            n = n->left;
          }} else if(n->right) {{
            n = n->right;
          }} else {{
            p = n->parent;
            if(p) {{
              if(p->left == n) p->left = NULL; else p->right = NULL;
            }}
            {_destroy};
            {self.memory.free("n")};
            n = p;
          }}
        }}
      """

    with self.method(Indirection(self._node_p), "link", {"target": inout(self), "node": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal") as f:
      f.code = f"""
        assert(target);
        assert(node);
        if(node->parent) return node->parent->left == node ? &node->parent->left : &node->parent->right;
        return &target->root;
      """

    with self.method(None, ("rotate", "left"), {"link": Callable.Parameter(Indirection(self._node_p))}, hidden=True, visibility="internal") as f:
      f.code = f"""
        {self.node}* n;
        {self.node}* pivot;
        n = *link;
        pivot = n->right;
        n->right = pivot->left;
        if(pivot->left) pivot->left->parent = n;
        pivot->parent = n->parent;
        pivot->left = n;
        n->parent = pivot;
        *link = pivot;
      """

    with self.method(None, ("rotate", "right"), {"link": Callable.Parameter(Indirection(self._node_p))}, hidden=True, visibility="internal") as f:
      f.code = f"""
        {self.node}* n;
        {self.node}* pivot;
        n = *link;
        pivot = n->left;
        n->left = pivot->right;
        if(pivot->right) pivot->right->parent = n;
        pivot->parent = n->parent;
        pivot->right = n;
        n->parent = pivot;
        *link = pivot;
      """

    with self.contains as f:
      f.code = f"""
        {self.node}* n;
        int order;
        assert(target);
        n = target->root;
        while(n) {{
          order = {self.element.compare(node_element, f.element)};
          if(order == 0) return 1;
          n = order > 0 ? n->left : n->right;
        }}
        return 0;
      """

    with self.put as f:
      f.code = f"""
        {self.node}* n;
        {self.node}* parent;
        {Indirection(self._node_p)} link;
        int order;
        assert(target);
        link = &target->root;
        parent = NULL;
        while(*link) {{
          order = {self.element.compare(link_element, f.element)};
          if(order == 0) return 0;
          parent = *link;
          link = order > 0 ? &parent->left : &parent->right;
        }}
        n = {self.memory.allocate(self.node)}; assert(n);
        {self.element.copy(node_element, f.element)};
        n->left = n->right = NULL;
        n->parent = parent;
        *link = n;
        ++target->size;
        while(n->parent && {self.randomizer.priority(node_parent)} < {self.randomizer.priority(node)}) {{
          if(n->parent->right == n) {{
            {self.rotate_left(self.link(f.target, "n->parent"))};
          }} else {{
            {self.rotate_right(self.link(f.target, "n->parent"))};
          }}
        }}
        return 1;
      """

    with self.remove as f:
      _destroy = self.element.destroy(node_element) if self.element.destructible else str()
      f.code = f"""
        {self.node}* n;
        {self.node}* child;
        int order;
        assert(target);
        n = target->root;
        while(n) {{
          order = {self.element.compare(node_element, f.element)};
          if(order == 0) break;
          n = order > 0 ? n->left : n->right;
        }}
        if(!n) return 0;
        while(n->left && n->right) {{
          if({self.randomizer.priority(node_left)} < {self.randomizer.priority(node_right)}) {{
            {self.rotate_left(self.link(f.target, "n"))};
          }} else {{
            {self.rotate_right(self.link(f.target, "n"))};
          }}
        }}
        child = n->left ? n->left : n->right;
        if(child) child->parent = n->parent;
        *{self.link(f.target, "n")} = child;
        {_destroy};
        {self.memory.free("n")};
        --target->size;
        return 1;
      """

    with self.method(self.element.view_type, ("find", "view"), {"target": self, "element": self.element}) as f:
      f.code = f"""
        {self.node}* n;
        int order;
        assert(target);
        n = target->root;
        while(n) {{
          order = {self.element.compare(node_element, f.element)};
          if(order == 0) return {node_element.bind(f.result)};
          n = order > 0 ? n->left : n->right;
        }}
        return ({self.element.view_type})0;
      """

    range = self.range
    r = range.variable("r")

    with self.copy as f:
      f.code = f"""
        {r.definition};
        assert(target);
        assert(source);
        {self.create(f.target)};
        for({r} = {range.new(f.source)}; !{range.empty(r)}; {range.move_front(r)}) {{
          {self.put(f.target, range.front_view(r))};
        }}
      """

    with self.move as f:
      f.code = f"""
        assert(target);
        assert(source);
        target->root = source->root;
        target->size = source->size;
        {self.create(f.source)};
      """

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

    rl = range.variable("left_r")
    rr = range.variable("right_r")

    with self.compare as f:
      f.code = f"""
        {rl.definition};
        {rr.definition};
        int order;
        assert(left);
        assert(right);
        for({rl} = {range.new(f.left)}, {rr} = {range.new(f.right)}; !{range.empty(rl)} && !{range.empty(rr)}; {range.move_front(rl)}, {range.move_front(rr)}) {{
          order = {self.element.compare(range.front_view(rl), range.front_view(rr))};
          if(order) return order;
        }}
        return {range.empty(rl)} ? ({range.empty(rr)} ? 0 : -1) : +1;
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
        {self.node}* left;
        {self.node}* right;
        {self.node}* parent;
      }};
    """)
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"""typedef struct {{
      {self._node_p} root; /**< @private */
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
          {self.iterable.node}* node; /**< @private */
        }} {self.name};
      """)

  def __setup__(self):
    super().__setup__()

    node_element = self.element.variable("target->node->element")

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(iterable);
        result.iterable = iterable;
        result.node = iterable->root;
        while(result.node && result.node->left) result.node = result.node->left;
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
      f.inline_code = f"""
        {self.iterable.node}* p;
        assert(target);
        assert(!{self.empty(f.target)});
        if(target->node->right) {{
          target->node = target->node->right;
          while(target->node->left) target->node = target->node->left;
        }} else {{
          p = target->node->parent;
          while(p && target->node == p->right) {{
            target->node = p;
            p = p->parent;
          }}
          target->node = p;
        }}
      """
