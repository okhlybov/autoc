import autoc.core
import autoc.std as std
from autoc.core import inout
from autoc.module import Code
from autoc.collection import Collection


#
class Set(Collection):

  brief = "" # TODO

  def __setup__(self):
    super().__setup__()

    self.method("int", "put", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable and self.element.comparable, brief="Puts the element into the set. Returns 1 when inserted, 0 when already present.")
    self.method("int", "remove", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.comparable, brief="Removes the element from the set. Returns 1 when removed, 0 when absent.")

    # The algebraic operations are composed entirely out of the protocol primitives so every
    # set implementation inherits them. They mutate the target in place and return the number
    # of the elements added, removed or changed. The bodies are built lazily because they call
    # the put/remove/contains operations which are inactive for the elements failing the traits.
    # The other set is the second operand - the self operations are shortcut
    range = self.range
    r = range.variable("r")
    temp = self.variable("temp")
    algebra_constraint = lambda: self.element.copyable and self.element.comparable

    with self.method("int", "union", {"target": inout(self), "other": self}, constraint=algebra_constraint, brief="Merges every element of the other set into the target. Returns the number added. The other set is left intact, except the treap implementation which consumes it.") as f:
      f.code = lambda f=f: f"""
        size_t added;
        {r.definition};
        assert(target);
        assert({f.other});
        if(target == {f.other}) return 0;
        added = 0;
        for({r} = {range.new(f.other)}; !{range.empty(r)}; {range.move_front(r)}) {{
          added += {self.put(f.target, range.front_view(r))};
        }}
        return added;
      """

    with self.method("int", "difference", {"target": inout(self), "other": self}, constraint=algebra_constraint, brief="Removes every element of the other set from the target. Returns the number removed. The other set is left intact, except the treap implementation which consumes it.") as f:
      f.code = lambda f=f: f"""
        size_t removed;
        {r.definition};
        assert(target);
        assert({f.other});
        if(target == {f.other}) {{
          removed = {self.size(f.target)};
          {self.destroy(f.target)};
          {self.create(f.target)};
          return removed;
        }}
        removed = 0;
        for({r} = {range.new(f.other)}; !{range.empty(r)}; {range.move_front(r)}) {{
          removed += {self.remove(f.target, range.front_view(r))};
        }}
        return removed;
      """

    with self.method("int", "intersection", {"target": inout(self), "other": self}, constraint=algebra_constraint, brief="Removes every element of the target absent from the other set. Returns the number removed. The other set is left intact, except the treap implementation which consumes it.") as f:
      f.code = lambda f=f: f"""
        size_t removed;
        {r.definition};
        {temp.definition};
        assert(target);
        assert({f.other});
        if(target == {f.other}) return 0;
        {self.create(temp)};
        {self.copy(temp, f.target)};
        removed = 0;
        for({r} = {range.new(temp)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if(!{self.contains(f.other, range.front_view(r))}) removed += {self.remove(f.target, range.front_view(r))};
        }}
        {self.destroy(temp)};
        return removed;
      """

    with self.method("int", ("symmetric", "difference"), {"target": inout(self), "other": self}, constraint=algebra_constraint, brief="Exchanges the membership keeping the uncommon elements. Returns the number of the elements added or removed. The other set is left intact, except the treap implementation which consumes it.") as f:
      f.code = lambda f=f: f"""
        size_t changed;
        {r.definition};
        assert(target);
        assert({f.other});
        if(target == {f.other}) {{
          changed = {self.size(f.target)};
          {self.destroy(f.target)};
          {self.create(f.target)};
          return changed;
        }}
        changed = 0;
        for({r} = {range.new(f.other)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if({self.contains(f.target, range.front_view(r))}) changed += {self.remove(f.target, range.front_view(r))};
          else changed += {self.put(f.target, range.front_view(r))};
        }}
        return changed;
      """

    with self.method("int", ("is", "subset"), {"target": self, "other": self}, constraint=lambda: self.element.comparable, brief="Checks whether the target is a subset of the other set.") as f:
      f.code = lambda f=f: f"""
        {r.definition};
        assert(target);
        assert({f.other});
        for({r} = {range.new(f.target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if(!{self.contains(f.other, range.front_view(r))}) return 0;
        }}
        return 1;
      """

    with self.method("int", ("is", "superset"), {"target": self, "other": self}, constraint=lambda: self.element.comparable, brief="Checks whether the target is a superset of the other set.") as f:
      f.code = lambda f=f: f"""
        {r.definition};
        assert(target);
        assert({f.other});
        for({r} = {range.new(f.other)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if(!{self.contains(f.target, range.front_view(r))}) return 0;
        }}
        return 1;
      """

      # TODO pop, ...


#
_ceil_power2 = Code(dependencies=(std.size_t, autoc.core._linkage_code), definitions="""
  AUTOC_EXTERN
  size_t _autoc_ceil_power2(size_t value);
""", implementation="""
  size_t _autoc_ceil_power2(size_t value) {
    if(value == 0) return 1;
    --value;
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    value |= value >> 8;
    value |= value >> 16;
    if(sizeof(size_t) >= 8) value |= value >> 32;
    return ++value;
  }
""")