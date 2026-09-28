import autoc.std as std
from autoc.set import Set
from autoc.range import Forward
from autoc.collection import _Range
from autoc.core import inout, _type, _StructRenderer, Indirection, Callable


#
class Set(_StructRenderer, Set):

  brief = "Ordered set of distinct values implemented as an AVL tree - iterates in sorted order"

  def __init__(self, *args, dependencies=(), **kws):
    super().__init__(*args, dependencies=dependencies, **kws)
    self.node = _type(self._decorate_component("node"))
    self._node_p = Indirection(self.node)
    self.range = Range(self)

  @property
  def orderable(self):
    return True

  @property
  def copyable(self):
    return self.element.copyable and self.element.comparable

  def __setup__(self):
    super().__setup__()

    self.description = f"""
      Requires the element type (@ref {self.element}) to be *Orderable*.
      Supports one way element traversal via the corresponding @ref {self.range} iterator - the elements are yielded in sorted order.

      Implemented as an AVL tree with strictly bounded height <= 1.44 * log2(n + 2).
      The closest C++ equivalent is [std::set<>](https://cppreference.com/cpp/container/set).
    """

    node_element = self.element.variable("n->element")
    curr_element = self.element.variable("curr->element")
    z_element = self.element.variable("z->element")

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

    with self.method(None, ("rotate", "left"), {"target": inout(self), "n": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", brief="Rotate left (internal)") as f:
      f.code = f"""
        {self.node}* r;
        int hl, hr;
        assert(target);
        assert(n);
        r = n->right;
        assert(r);
        n->right = r->left;
        if(r->left) r->left->parent = n;
        r->parent = n->parent;
        if(!n->parent) target->root = r;
        else if(n == n->parent->left) n->parent->left = r;
        else n->parent->right = r;
        r->left = n;
        n->parent = r;
        hl = n->left ? n->left->height : 0;
        hr = n->right ? n->right->height : 0;
        n->height = (hl > hr ? hl : hr) + 1;
        hl = r->left ? r->left->height : 0;
        hr = r->right ? r->right->height : 0;
        r->height = (hl > hr ? hl : hr) + 1;
      """

    with self.method(None, ("rotate", "right"), {"target": inout(self), "n": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", brief="Rotate right (internal)") as f:
      f.code = f"""
        {self.node}* l;
        int hl, hr;
        assert(target);
        assert(n);
        l = n->left;
        assert(l);
        n->left = l->right;
        if(l->right) l->right->parent = n;
        l->parent = n->parent;
        if(!n->parent) target->root = l;
        else if(n == n->parent->left) n->parent->left = l;
        else n->parent->right = l;
        l->right = n;
        n->parent = l;
        hl = n->left ? n->left->height : 0;
        hr = n->right ? n->right->height : 0;
        n->height = (hl > hr ? hl : hr) + 1;
        hl = l->left ? l->left->height : 0;
        hr = l->right ? l->right->height : 0;
        l->height = (hl > hr ? hl : hr) + 1;
      """

    with self.method(Callable.Parameter(self._node_p), ("rebalance", "node"), {"target": inout(self), "p": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", brief="Rebalance AVL node (internal)") as f:
      f.code = f"""
        int hl, hr, bf;
        assert(target);
        assert(p);
        hl = p->left ? p->left->height : 0;
        hr = p->right ? p->right->height : 0;
        bf = hl - hr;
        p->height = (hl > hr ? hl : hr) + 1;
        if(bf > 1) {{
          int l_hl = p->left->left ? p->left->left->height : 0;
          int l_hr = p->left->right ? p->left->right->height : 0;
          if(l_hl >= l_hr) {{
            {self.rotate_right(f.target, f.p)};
          }} else {{
            {self.rotate_left(f.target, f"{f.p}->left")};
            {self.rotate_right(f.target, f.p)};
          }}
          return {f.p}->parent;
        }} else if(bf < -1) {{
          int r_hl = p->right->left ? p->right->left->height : 0;
          int r_hr = p->right->right ? p->right->right->height : 0;
          if(r_hr >= r_hl) {{
            {self.rotate_left(f.target, f.p)};
          }} else {{
            {self.rotate_right(f.target, f"{f.p}->right")};
            {self.rotate_left(f.target, f.p)};
          }}
          return {f.p}->parent;
        }}
        return {f.p};
      """

    with self.method(None, "transplant", {"target": inout(self), "u": Callable.Parameter(self._node_p), "v": Callable.Parameter(self._node_p)}, hidden=True, visibility="internal", brief="Transplant subtrees (internal)") as f:
      f.code = f"""
        assert(target);
        assert(u);
        if(!u->parent) target->root = v;
        else if(u == u->parent->left) u->parent->left = v;
        else u->parent->right = v;
        if(v) v->parent = u->parent;
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

    with self.method(self.element.view_type, ("find", "view"), {"target": self, "element": self.element}, brief="Find element and return view",
      description="""
        Descends the AVL tree from the root comparing the elements - guaranteed O(log n).
        The returned view points into the found node and stays valid while the element is held by the set.

        @param[in] target the set to search
        @param[in] element the element to look for
        @return a constant view of the found element or NULL when absent
      """) as f:
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

    with self.put as f:
      f.code = f"""
        {self.node}* n;
        {self.node}* parent;
        {self.node}* curr;
        {self.node}* p;
        int order = 0;
        assert(target);
        parent = NULL;
        curr = target->root;
        while(curr) {{
          order = {self.element.compare(curr_element, f.element)};
          if(order == 0) return 0;
          parent = curr;
          curr = order > 0 ? curr->left : curr->right;
        }}
        n = {self.memory.allocate(self.node)};
        {self.element.copy(node_element, f.element)};
        n->left = n->right = NULL;
        n->parent = parent;
        n->height = 1;
        if(!parent) target->root = n;
        else if(order > 0) parent->left = n;
        else parent->right = n;
        ++target->size;

        /* Rebalance: bottom-up */
        p = parent;
        while(p) {{
          int old_height = p->height;
          p = {self.rebalance_node(f.target, "p")};
          if(p->height == old_height) break;
          p = p->parent;
        }}
        return 1;
      """

    with self.remove as f:
      _destroy_z_element = self.element.destroy(z_element) if self.element.destructible else str()
      f.code = f"""
        {self.node}* z;
        {self.node}* y;
        {self.node}* p;
        {self.node}* start_rebalance;
        int order;
        assert(target);
        z = target->root;
        while(z) {{
          order = {self.element.compare(z_element, f.element)};
          if(order == 0) break;
          z = order > 0 ? z->left : z->right;
        }}
        if(!z) return 0;

        if(!z->left) {{
          start_rebalance = z->parent;
          {self.transplant(f.target, "z", "z->right")};
        }} else if(!z->right) {{
          start_rebalance = z->parent;
          {self.transplant(f.target, "z", "z->left")};
        }} else {{
          y = z->right;
          while(y->left) y = y->left;
          if(y->parent == z) {{
            start_rebalance = y;
          }} else {{
            start_rebalance = y->parent;
            {self.transplant(f.target, "y", "y->right")};
            y->right = z->right;
            y->right->parent = y;
          }}
          {self.transplant(f.target, "z", "y")};
          y->left = z->left;
          y->left->parent = y;
          y->height = z->height;
        }}

        {_destroy_z_element};
        {self.memory.free("z")};
        --target->size;

        p = start_rebalance;
        while(p) {{
          p = {self.rebalance_node(f.target, "p")};
          p = p->parent;
        }}
        return 1;
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
        int height; /**< @private */
      }};
    """)
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self._node_p} root; /**< @private */
        {std.size_t} size; /**< @private */
      }};
    """)


#
class Range(_Range, Forward):

  brief = "Forward range over the set elements"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {Indirection(self.iterable, constant=True)} iterable; /**< @private */
        {self.iterable.node}* node; /**< @private */
      }};
    """)

  def __setup__(self):
    super().__setup__()

    node_element = self.element.variable("target->node->element")

    with self.method(Callable.Parameter(self), "new", {"iterable": self.iterable}, brief="Create the range spanning the whole set",
      description="""
        Creates the range over the AVL tree descending to the leftmost node so the traversal
        starts at the smallest element and proceeds in ascending order. The range must not
        outlive the set and the set must not be modified while the range is traversed.

        @param[in] iterable the set to span
        @return the range covering the whole set in ascending order
      """) as f:
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
