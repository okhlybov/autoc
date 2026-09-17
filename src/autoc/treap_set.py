import autoc.std as std
from autoc.set import Set
from autoc.range import Forward
from autoc.collection import _Range
from autoc.random import Randomizer
from autoc.core import inout, out, _type, _StructRenderer, Indirection, Callable, Expression


#
class Set(_StructRenderer, Set):

  brief = "Ordered set of distinct values implemented as a treap - iterates in sorted order"
  
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

    with self.method(Indirection(self._node_p), "link", {"target": inout(self), "node": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", brief="Get link to node (internal)") as f:
      f.code = f"""
        assert(target);
        assert(node);
        if(node->parent) return node->parent->left == node ? &node->parent->left : &node->parent->right;
        return &target->root;
      """

    with self.method(None, ("rotate", "left"), {"link": Callable.Parameter(Indirection(self._node_p))}, hidden=True, visibility="internal", brief="Rotate left at link (internal)") as f:
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

    with self.method(None, ("rotate", "right"), {"link": Callable.Parameter(Indirection(self._node_p))}, hidden=True, visibility="internal", brief="Rotate right at link (internal)") as f:
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

    with self.method(self.element.view_type, ("find", "view"), {"target": self, "element": self.element}, brief="Find element and return view") as f:
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

    # The treap algebra: the split and the merge node operations give the O(m log(n/m))
    # implementations of the algebraic operations. Both operands are consumed - their nodes
    # are reused without copying and the other set is left empty. The parent links and the
    # element resources are maintained throughout

    with self.method(self._node_p, ("merge", "nodes"), {"left": Callable.Parameter(self._node_p), "right": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", brief="Merge two node trees (internal)") as f:
      f.code = f"""
        if(!{f.left}) return {f.right};
        if(!{f.right}) return {f.left};
        if({self.randomizer.priority(str(f.left))} > {self.randomizer.priority(str(f.right))}) {{
          {f.left}->right = {self.merge_nodes(f"{f.left}->right", f.right)};
          if({f.left}->right) {f.left}->right->parent = {f.left};
          return {f.left};
        }}
        {f.right}->left = {self.merge_nodes(f.left, f"{f.right}->left")};
        if({f.right}->left) {f.right}->left->parent = {f.right};
        return {f.right};
      """

    with self.method(None, ("split", "nodes"), {"tree": Callable.Parameter(self._node_p), "key": self.element, "left": out(Indirection(self._node_p)), "right": out(Indirection(self._node_p))}, hidden=True, visibility="internal", brief="Split node tree by key (internal)") as f:
      f.code = f"""
        assert({f.left});
        assert({f.right});
        if(!{f.tree}) {{
          *{f.left} = *{f.right} = NULL;
          return;
        }}
        if({self.element.compare(self.element.variable(f"{f.tree}->element"), f.key)} < 0) {{
          {self.split_nodes(f"{f.tree}->right", f.key, f"&{f.tree}->right", f.right)};
          if({f.tree}->right) {f.tree}->right->parent = {f.tree};
          *{f.left} = {f.tree};
        }} else {{
          {self.split_nodes(f"{f.tree}->left", f.key, f.left, f"&{f.tree}->left")};
          if({f.tree}->left) {f.tree}->left->parent = {f.tree};
          *{f.right} = {f.tree};
        }}
      """

    with self.method("int", ("discard", "equal"), {"root": inout(Indirection(self._node_p)), "key": self.element}, hidden=True, visibility="internal", brief="Discard element matching key (internal)") as f:
      destroy_element = str(self.element.destroy(self.element.variable("n->element"))) + ";" if self.element.destructible else str()
      f.code = f"""
        int order;
        {self.node}* n;
        {self.node}* parent;
        {self.node}* merged;
        n = *{f.root};
        parent = NULL;
        while(n) {{
          order = {self.element.compare(self.element.variable("n->element"), f.key)};
          if(order == 0) break;
          parent = n;
          n = order > 0 ? n->left : n->right;
        }}
        if(!n) return 0;
        merged = {self.merge_nodes("n->left", "n->right")};
        if(parent) {{
          if(parent->left == n) parent->left = merged; else parent->right = merged;
          if(merged) merged->parent = parent;
        }} else {{
          *{f.root} = merged;
          if(merged) merged->parent = NULL;
        }}
        {destroy_element}
        {self.memory.free("n")};
        return 1;
      """

    with self.method(None, ("destroy", "root"), {"root": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", brief="Destroy node tree (internal)") as f:
      destroy_element = str(self.element.destroy(self.element.variable("n->element"))) + ";" if self.element.destructible else str()
      f.code = f"""
        {self.node}* n;
        {self.node}* p;
        if({f.root}) {f.root}->parent = NULL; /* detached trees carry stale root parents */
        n = {f.root};
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
            {destroy_element}
            {self.memory.free("n")};
            n = p;
          }}
        }}
      """

    with self.method(std.size_t, "count", {"node": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", brief="Count nodes in tree (internal)") as f:
      f.code = f"""
        if(!{f.node}) return 0;
        return 1 + {self.count(f"{f.node}->left")} + {self.count(f"{f.node}->right")};
      """

    with self.method(self._node_p, ('union', 'nodes'), {"a": Callable.Parameter(self._node_p), "b": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", constraint=lambda: self.element.copyable and self.element.comparable, brief="Union of two node trees (internal)") as f:
      f.code = lambda f=f: f"""
        {self.node}* low;
        {self.node}* high;
        int taken;
        if(!{f.a}) {{
          return {f.b};
        }}
        if(!{f.b}) return {f.a};
        if({self.randomizer.priority(str(f.a))} < {self.randomizer.priority(str(f.b))}) {{
          {self.node}* swap = {f.a};
          {f.a} = {f.b};
          {f.b} = swap;
        }}
        {self.split_nodes(f.b, self.element.variable(f"{f.a}->element"), "&low", "&high")};
        taken = {self.discard_equal("&high", self.element.variable(f"{f.a}->element"))};
        {f.a}->left = {self.union_nodes(f"{f.a}->left", "low")};
        {f.a}->right = {self.union_nodes(f"{f.a}->right", "high")};
        if({f.a}->left) {f.a}->left->parent = {f.a};
        if({f.a}->right) {f.a}->right->parent = {f.a};
        return {f.a};
      """

    with self.method(self._node_p, ('intersection', 'nodes'), {"a": Callable.Parameter(self._node_p), "b": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", constraint=lambda: self.element.copyable and self.element.comparable, brief="Intersect two node trees (internal)") as f:
      f.code = lambda f=f: f"""
        {self.node}* low;
        {self.node}* high;
        int taken;
        if(!{f.a}) {{
          {self.destroy_root(f.b)};
          return NULL;
        }}
        if(!{f.b}) {{
          {self.destroy_root(f.a)};
          return NULL;
        }}
        if({self.randomizer.priority(str(f.a))} < {self.randomizer.priority(str(f.b))}) {{
          {self.node}* swap = {f.a};
          {f.a} = {f.b};
          {f.b} = swap;
        }}
        {self.split_nodes(f.b, self.element.variable(f"{f.a}->element"), "&low", "&high")};
        taken = {self.discard_equal("&high", self.element.variable(f"{f.a}->element"))};
        {f.a}->left = {self.intersection_nodes(f"{f.a}->left", "low")};
        {f.a}->right = {self.intersection_nodes(f"{f.a}->right", "high")};
        if({f.a}->left) {f.a}->left->parent = {f.a};
        if({f.a}->right) {f.a}->right->parent = {f.a};
        if(taken) return {f.a};
        {self.node}* left_result = {f.a}->left;
        {self.node}* right_result = {f.a}->right;
        {str(self.element.destroy(self.element.variable(f"{f.a}->element"))) + ";" if self.element.destructible else str()}
        {self.memory.free(f.a)};
        return {self.merge_nodes("left_result", "right_result")};
      """

    with self.method(self._node_p, ('difference', 'nodes'), {"a": Callable.Parameter(self._node_p), "b": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", constraint=lambda: self.element.copyable and self.element.comparable, brief="Difference of two node trees (internal)") as f:
      f.code = lambda f=f: f"""
        {self.node}* low;
        {self.node}* high;
        int taken;
        if(!{f.a}) {{
          {self.destroy_root(f.b)};
          return NULL;
        }}
        if(!{f.b}) return {f.a};
        /* the difference is asymmetric - the priorities of a govern the recursion */
        {self.split_nodes(f.b, self.element.variable(f"{f.a}->element"), "&low", "&high")};
        taken = {self.discard_equal("&high", self.element.variable(f"{f.a}->element"))};
        {f.a}->left = {self.difference_nodes(f"{f.a}->left", "low")};
        {f.a}->right = {self.difference_nodes(f"{f.a}->right", "high")};
        if({f.a}->left) {f.a}->left->parent = {f.a};
        if({f.a}->right) {f.a}->right->parent = {f.a};
        if(taken) {{
          {self.node}* left_result = {f.a}->left;
          {self.node}* right_result = {f.a}->right;
          {str(self.element.destroy(self.element.variable(f"{f.a}->element"))) + ";" if self.element.destructible else str()}
          {self.memory.free(f.a)};
          return {self.merge_nodes("left_result", "right_result")};
        }}
        return {f.a};
      """

    with self.method(self._node_p, ('symmetric_difference', 'nodes'), {"a": Callable.Parameter(self._node_p), "b": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", constraint=lambda: self.element.copyable and self.element.comparable, brief="Symmetric difference of two node trees (internal)") as f:
      f.code = lambda f=f: f"""
        {self.node}* low;
        {self.node}* high;
        int taken;
        if(!{f.a}) {{
          return {f.b};
        }}
        if(!{f.b}) return {f.a};
        if({self.randomizer.priority(str(f.a))} < {self.randomizer.priority(str(f.b))}) {{
          {self.node}* swap = {f.a};
          {f.a} = {f.b};
          {f.b} = swap;
        }}
        {self.split_nodes(f.b, self.element.variable(f"{f.a}->element"), "&low", "&high")};
        taken = {self.discard_equal("&high", self.element.variable(f"{f.a}->element"))};
        {f.a}->left = {self.symmetric_difference_nodes(f"{f.a}->left", "low")};
        {f.a}->right = {self.symmetric_difference_nodes(f"{f.a}->right", "high")};
        if({f.a}->left) {f.a}->left->parent = {f.a};
        if({f.a}->right) {f.a}->right->parent = {f.a};
        if(taken) {{
          {self.node}* left_result = {f.a}->left;
          {self.node}* right_result = {f.a}->right;
          {str(self.element.destroy(self.element.variable(f"{f.a}->element"))) + ";" if self.element.destructible else str()}
          {self.memory.free(f.a)};
          return {self.merge_nodes("left_result", "right_result")};
        }}
        return {f.a};
      """

    # The consuming implementations of the algebraic operations: both operands are merged
    # at the node level and the other set is left empty
    with self.method("int", "union", {"target": inout(self), "other": inout(self)}, constraint=lambda: self.element.copyable and self.element.comparable, brief="Add all elements from other set") as f:
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      f.code = f"""
        size_t previous;
        assert(target);
        assert({f.other});
        if(target == {f.other}) return 0;
        previous = target->size;
        target->root = {self.union_nodes("target->root", other_root)};
        if(target->root) target->root->parent = NULL;
        {f.other}->root = NULL;
        {f.other}->size = 0;
        target->size = {self.count("target->root")};
        return target->size - previous;
      """

    with self.method("int", "difference", {"target": inout(self), "other": inout(self)}, constraint=lambda: self.element.copyable and self.element.comparable, brief="Remove all elements found in other set") as f:
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      f.code = f"""
        size_t previous;
        assert(target);
        assert({f.other});
        if(target == {f.other}) {{
          previous = target->size;
          {self.destroy(f.target)};
          {self.create(f.target)};
          return previous;
        }}
        previous = target->size;
        target->root = {self.difference_nodes("target->root", other_root)};
        if(target->root) target->root->parent = NULL;
        {f.other}->root = NULL;
        {f.other}->size = 0;
        target->size = {self.count("target->root")};
        return previous - target->size;
      """

    with self.method("int", "intersection", {"target": inout(self), "other": inout(self)}, constraint=lambda: self.element.copyable and self.element.comparable, brief="Keep only elements also present in other set") as f:
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      other_root = f"{f.other}->root"
      f.code = f"""
        size_t previous;
        assert(target);
        assert({f.other});
        if(target == {f.other}) return 0;
        previous = target->size;
        target->root = {self.intersection_nodes("target->root", other_root)};
        if(target->root) target->root->parent = NULL;
        {f.other}->root = NULL;
        {f.other}->size = 0;
        target->size = {self.count("target->root")};
        return previous - target->size;
      """

    with self.method("int", ("symmetric", "difference"), {"target": inout(self), "other": inout(self)}, constraint=lambda: self.element.copyable and self.element.comparable, brief="Remove elements in both sets, add elements in only one") as f:
      f.code = f"""
        size_t previous, other_size;
        assert(target);
        assert({f.other});
        if(target == {f.other}) {{
          previous = target->size;
          {self.destroy(f.target)};
          {self.create(f.target)};
          return previous;
        }}
        previous = target->size;
        other_size = {f.other}->size;
        target->root = {self.symmetric_difference_nodes("target->root", other_root)};
        if(target->root) target->root->parent = NULL;
        {f.other}->root = NULL;
        {f.other}->size = 0;
        target->size = {self.count("target->root")};
        return other_size; /* every element of the other set is either added or causes a removal */
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

  def _render_struct(self, stream, header):
    stream.append(f"""
      /** @private */
      typedef struct {self.node} {self.node};
      /** @private */
      struct {self.node} {{
        {self.element} element;
        {self.node}* left;
        {self.node}* right;
        {self.node}* parent;
      }};
    """)
    super()._render_struct(stream, header)
    stream.append(f"""
      typedef struct {{
        {self._node_p} root; /**< @private */
        {std.size_t} size; /**< @private */
      }} {self.name};
    """)


#
class Range(_Range, Forward):

  brief = "Forward range over the set elements"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      typedef struct {{
        {Indirection(self.iterable, constant=True)} iterable; /**< @private */
        {self.iterable.node}* node; /**< @private */
      }} {self.name};
    """)

  def __setup__(self):
    super().__setup__()

    node_element = self.element.variable("target->node->element")

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create the range spanning the whole set") as f:
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
