import autoc.std as std
from autoc.core import inout, Callable, enforced, Comparable
from autoc.traversable import Traversable
from autoc.insertable import Insertable


# Abstract base for all multiset collections
class Multiset(Traversable, Insertable):

  @enforced
  def __init__(self, name: str, element: Comparable, *args, algebraic_operations=True, **kws):
    self.algebraic_operations = bool(algebraic_operations)
    super().__init__(name, element, *args, **kws)
    self.element = self.element.require(Comparable, self, "element type")

  def __setup__(self):
    super().__setup__()

    self.method("int", "put", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.copyable and self.element.comparable, brief="Insert element into multiset",
      description="""
        Inserts the element into the multiset, preserving any existing duplicates.
        Every multiset implementation inherits this protocol operation.

        @param[in,out] target the multiset to insert into
        @param[in] element the element to insert
        @return always non-zero
      """)

    self.method("int", "emplace", {"target": inout(self)} | self.element.constructor_parameters,
      constraint=lambda: self.element.emplaceable and self.element.comparable,
      brief="Construct element in-place",
      description="""
        Constructs an element in-place with forwarded parameters and inserts it into the
        multiset, preserving any existing duplicates.
        Every multiset implementation inherits this protocol operation.
        Returns non-zero indicating the element was inserted.

        @param[in,out] target the multiset to insert into
        @return non-zero once the constructed element was inserted
      """)

    self.method("int", "remove", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.comparable, brief="Remove one occurrence of element",
      description="""
        Removes one occurrence of the element if present, leaving the multiset unchanged otherwise.
        Every multiset implementation inherits this protocol operation.

        @param[in,out] target the multiset to remove from
        @param[in] element the element to remove
        @return non-zero if an element was removed and zero if the multiset held no equal element
      """)

    self.method(std.size_t, "wipe", {"target": inout(self), "element": self.element}, constraint=lambda: self.element.comparable, brief="Remove all occurrences of element",
      description="""
        Removes all occurrences of the element from the multiset.
        Every multiset implementation inherits this protocol operation.

        @param[in,out] target the multiset to remove from
        @param[in] element the element to remove
        @return the number of occurrences removed
      """)

    self.method(std.size_t, "count", {"target": self, "element": self.element}, constraint=lambda: self.element.comparable, brief="Count occurrences of element",
      description="""
        Returns the multiplicity (number of occurrences) of the element in the multiset.
        Every multiset implementation inherits this protocol operation.

        @param[in] target the multiset to query
        @param[in] element the element to count
        @return number of occurrences
      """)

    self.method(Callable.Parameter(self.range), ("equal", "range"), {"target": self, "element": self.element}, constraint=lambda: self.element.comparable, brief="Get range covering all occurrences of element",
      description="""
        Returns the range covering all occurrences of the element in the multiset.
        If the element is absent, an empty range is returned.

        @param[in] target the multiset to search
        @param[in] element the element to search for
        @return the range spanning all matching occurrences
      """)

    range = self.range
    r = range.variable("r")
    temp = self.variable("temp")
    algebra_constraint = lambda: self.algebraic_operations and self.element.copyable and self.element.comparable
    subset_constraint = lambda: self.algebraic_operations and self.element.comparable

    with self.method("int", "union", {"target": inout(self), "other": self}, constraint=algebra_constraint, optional_group="algebraic_operations", brief="Multiset union (maximum multiplicities)",
      description="""
        Expands the target multiset so that the multiplicity of each element becomes the maximum
        of its multiplicities in the target and in other.
        Cost is O(m) operations where m is the other multiset's size.

        @param[in,out] target the multiset to update
        @param[in] other the multiset to union with - target itself is allowed and keeps it unchanged
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
          if({self.count(f.target, range.front_view(r))} < {self.count(f.other, range.front_view(r))}) {{
            added += {self.put(f.target, range.front_view(r))};
          }}
        }}
        return added;
      """

    with self.method("int", "difference", {"target": inout(self), "other": self}, constraint=algebra_constraint, optional_group="algebraic_operations", brief="Multiset difference (subtract multiplicities)",
      description="""
        Subtracts the multiplicity of each element in other from the multiplicity in target.
        Cost is O(m) calls to `remove` where m is the other multiset's size.

        @param[in,out] target the multiset to subtract from
        @param[in] other the multiset whose occurrences are subtracted - target itself is allowed and empties it in place
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

    with self.method("int", "intersection", {"target": inout(self), "other": self}, constraint=algebra_constraint, optional_group="algebraic_operations", brief="Multiset intersection (minimum multiplicities)",
      description="""
        Reduces the multiplicity of each element in target to the minimum of its multiplicities
        in target and in other.
        Cost is O(n) operations where n is the target size plus copy cost.

        @param[in,out] target the multiset to intersect
        @param[in] other the multiset to intersect with - target itself is allowed and keeps it unchanged
        @return the number of elements removed
      """) as f:
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
          if({self.count(f.target, range.front_view(r))} > {self.count(f.other, range.front_view(r))}) {{
            removed += {self.remove(f.target, range.front_view(r))};
          }}
        }}
        {self.destroy(temp)};
        return removed;
      """

    with self.method("int", ("symmetric", "difference"), {"target": inout(self), "other": self}, constraint=algebra_constraint, optional_group="algebraic_operations", brief="Multiset symmetric difference (absolute difference of multiplicities)",
      description="""
        Sets the multiplicity of each element in target to the absolute difference |m_target - m_other|.
        The target itself is allowed and empties it in place.

        @param[in,out] target the multiset to update
        @param[in] other the multiset to compare against
        @return the number of elements added or removed
      """) as f:
      f.code = lambda f=f: f"""
        size_t changed;
        {r.definition};
        {temp.definition};
        assert(target);
        assert({f.other});
        if(target == {f.other}) {{
          changed = {self.size(f.target)};
          {self.destroy(f.target)};
          {self.create(f.target)};
          return changed;
        }}
        {self.create(temp)};
        for({r} = {range.new(f.other)}; !{range.empty(r)}; {range.move_front(r)}) {{
          {self.put(temp, range.front_view(r))};
        }}
        for({r} = {range.new(f.target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          {self.remove(temp, range.front_view(r))};
        }}
        changed = {self.difference(f.target, f.other)};
        for({r} = {range.new(temp)}; !{range.empty(r)}; {range.move_front(r)}) {{
          changed += {self.put(f.target, range.front_view(r))};
        }}
        {self.destroy(temp)};
        return changed;
      """

    with self.method("int", ("is", "subset"), {"target": self, "other": self}, constraint=subset_constraint, optional_group="algebraic_operations", brief="Check if target is a sub-multiset of other",
      description="""
        Checks whether for every element in target, its multiplicity in target does not exceed
        its multiplicity in other.

        @param[in] target the candidate sub-multiset
        @param[in] other the candidate super-multiset
        @return non-zero if target is a sub-multiset of other, zero otherwise
      """) as f:
      f.code = lambda f=f: f"""
        {r.definition};
        assert(target);
        assert({f.other});
        if(target == {f.other}) return 1;
        if({self.size(f.target)} > {self.size(f.other)}) return 0;
        for({r} = {range.new(f.target)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if({self.count(f.target, range.front_view(r))} > {self.count(f.other, range.front_view(r))}) return 0;
        }}
        return 1;
      """

    with self.method("int", ("is", "superset"), {"target": self, "other": self}, constraint=subset_constraint, optional_group="algebraic_operations", brief="Check if target is a super-multiset of other",
      description="""
        Checks whether for every element in other, its multiplicity in other does not exceed
        its multiplicity in target.

        @param[in] target the candidate super-multiset
        @param[in] other the candidate sub-multiset
        @return non-zero if target is a super-multiset of other, zero otherwise
      """) as f:
      f.code = lambda f=f: f"""
        {r.definition};
        assert(target);
        assert({f.other});
        if(target == {f.other}) return 1;
        if({self.size(f.other)} > {self.size(f.target)}) return 0;
        for({r} = {range.new(f.other)}; !{range.empty(r)}; {range.move_front(r)}) {{
          if({self.count(f.other, range.front_view(r))} > {self.count(f.target, range.front_view(r))}) return 0;
        }}
        return 1;
      """
