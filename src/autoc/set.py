import autoc.core
import autoc.std as std
from autoc.core import inout
from autoc.module import Code
from autoc.collection import Collection


#
class Set(Collection):
  
  def __setup__(self):
    super().__setup__()
    
    self.method("int", "put", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable and self.element.comparable, brief="Insert element if not present",
      description="""
        @param[in,out] target the set to insert into
        @param[in] element the element to insert - ignored when the set already holds an equal element
        @return non-zero if the element was inserted and zero if an equal element was already present
      """)
    self.method("int", "remove", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.comparable, brief="Remove element if present",
      description="""
        @param[in,out] target the set to remove from
        @param[in] element the element to remove
        @return non-zero if the element was removed and zero if the set held no equal element
      """)

    # The algebraic operations are composed entirely out of the protocol primitives so every
    # set implementation inherits them. They mutate the target in place and return the number
    # of the elements added, removed or changed. The bodies are built lazily because they call
    # the put/remove/contains operations which are inactive for the elements failing the traits.
    # The other set is the second operand - the self operations are shortcut
    range = self.range
    r = range.variable("r")
    temp = self.variable("temp")
    algebra_constraint = lambda: self.element.copyable and self.element.comparable

    with self.method("int", "union", {"target": inout(self), "other": self}, constraint=algebra_constraint, brief="Add all elements from other set",
      description="""
        @param[in,out] target the set to add the elements to
        @param[in] other the set whose elements are added - the target itself is allowed and keeps it unchanged
        @return the number of elements added
      """) as f:
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

    with self.method("int", "difference", {"target": inout(self), "other": self}, constraint=algebra_constraint, brief="Remove all elements found in other set",
      description="""
        @param[in,out] target the set to remove the elements from
        @param[in] other the set whose elements are removed - the target itself is allowed and empties it in place
        @return the number of elements removed
      """) as f:
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

    with self.method("int", "intersection", {"target": inout(self), "other": self}, constraint=algebra_constraint, brief="Keep only elements also present in other set",
      description="""
        @param[in,out] target the set to keep the elements in
        @param[in] other the set to intersect with - the target itself is allowed and keeps it unchanged
        @return the number of elements removed
      """) as f:
      f.code = lambda f=f: f"""
        size_t removed;
        {r.definition};
        {temp.definition};
        assert(target);
        assert({f.other});
        if(target == {f.other}) return 0; /* nothing is removed intersecting with self */
        {self.create(temp)};
        {self.copy(temp, f.target)};
        removed = 0;
        for({r} = {range.new(temp)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if(!{self.contains(f.other, range.front_view(r))}) removed += {self.remove(f.target, range.front_view(r))};
        }}
        {self.destroy(temp)};
        return removed;
      """

    with self.method("int", ("symmetric", "difference"), {"target": inout(self), "other": self}, constraint=algebra_constraint, brief="Remove elements in both sets, add elements in only one",
      description="""
        @param[in,out] target the set to change
        @param[in] other the set to change the target by - the target itself is allowed and empties it in place
        @return the number of elements added or removed
      """) as f:
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

    with self.method("int", ("is", "subset"), {"target": self, "other": self}, constraint=lambda: self.element.comparable, brief="Check if all elements are in other set",
      description="""
        @param[in] target the set to test
        @param[in] other the set to test against
        @return non-zero if every element of the target is also present in the other set
      """) as f:
      f.code = lambda f=f: f"""
        {r.definition};
        assert(target);
        assert({f.other});
        for({r} = {range.new(f.target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if(!{self.contains(f.other, range.front_view(r))}) return 0;
        }}
        return 1;
      """

    with self.method("int", ("is", "superset"), {"target": self, "other": self}, constraint=lambda: self.element.comparable, brief="Check if all elements of other are in this set",
      description="""
        @param[in] target the set to test against
        @param[in] other the set to test
        @return non-zero if every element of the other set is also present in the target
      """) as f:
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