import autoc.std as std
from autoc.hash import XorRot
from autoc.core import inout, _type
from autoc.core import Composite


#
# Common base of the optional types.
#
# An optional value is a small state machine over the element storage: state 0 is the
# empty state (the technically specified one), state 1 is the engaged state holding the
# element value and states 2 and beyond are of pure user-defined meaning (value-less,
# like the empty state itself). The base is parameterized by a state codec - a set of
# per-state test/mark emitters over the storage expression - and derives the whole
# value protocol plus the optional-specific operations from it.
#
# The plain Optional supplies a codec over an internally stored integer tag while the
# IntrusiveOptional takes user-supplied codecs encoding the states as sentinel element
# values, exactly like the intrusive hash containers encode their slot states.
class Optional(Composite):

  brief = "Optional value holding either an element or one of the named states"

  def __init__(self, name, element, *args, hasher=XorRot(), dependencies=(), **kwargs):
    super().__init__(name, *args, dependencies=(*dependencies, std.assert_h, hasher), **kwargs)
    self.element = _type(element)
    self.hasher = hasher
    self.dependencies.add(self.element)

  # State codec hooks -------------------------------------------------------
  # _is(state) -> emitter testing whether the storage expression is in the given state
  # _mark(state) -> emitter bringing the storage expression into the given state
  # _slot(storage) -> element storage expression of the optional value expression

  # The engaged test is the absence of every value-less state
  def _engaged(self, e):
    tests = [self._is(s)(e) for s in range(self.nstates) if s != 1]
    return "!(" + " || ".join(f"({t})" for t in tests) + ")"

  def __setup__(self):
    super().__setup__()
    element = self.element
    e = "(*target)"

    with self.create as f:
      f.inline_code = f"""
        assert(target);
        {self._mark(0)(e)};
      """

    destroy_slot = element.destroy(self._slot_var(e)) if element.destructible else str()
    with self.destroy as f:
      f.inline_code = f"""
        assert(target);
        if({self._engaged(e)}) {{{destroy_slot};}}
      """

    with self.copy as f:
      f.inline_code = f"""
        assert(target);
        assert(source);
        if({self._engaged("(*source)")}) {{
          {element.copy(self._slot_var(e), self._slot_var("(*source)"))};
        }}
        {self._mark_states_from(e, "(*source)")};
      """

    with self.move as f:
      f.inline_code = f"""
        assert(target);
        assert(source);
        if({self._engaged("(*source)")}) {{
          {element.move(self._slot_var(e), self._slot_var("(*source)"))};
        }}
        {self._mark_states_from(e, "(*source)")};
        {self._mark(0)("(*source)")};
      """

    # The generic swap exchanges the two values through the move protocol - a plain
    # struct exchange would shallow-copy the element leaving both sides owning it
    with self.swap as f:
      temp = self.variable("temp")
      f.inline_code = f"""
        {temp.definition};
        assert(left);
        assert(right);
        {self.create(temp)};
        {self.move(temp, f.left)};
        {self.move(f.left, f.right)};
        {self.move(f.right, temp)};
        {self.destroy(temp)};
      """

    with self.equal as f:
      state_diff = [f"if({self._is(s)(f'(*left)')} != {self._is(s)(f'(*right)')}) return 0;" for s in range(self.nstates) if s != 1]
      f.inline_code = [f"assert(left);", f"assert(right);", *state_diff,
                       f"if({self._is(0)('(*left)')}) return 1;",
                       f"return {element.equal(self._slot_var('(*left)'), self._slot_var('(*right)'))};"]

    with self.compare as f:
      # empty orders before the value which orders before the user states in index order
      def side(e):
        chain = [f"{self._is(s)(e)} ? {s} : " for s in range(2, self.nstates)]
        return f"({''.join(chain)}1)"
      f.inline_code = [f"assert(left);", f"assert(right);",
                       f"int l = {side('(*left)')}, r = {side('(*right)')};",
                       f"if(l != r) return l < r ? -1 : +1;",
                       f"if(l != 1) return 0;",
                       f"return {element.compare(self._slot_var('(*left)'), self._slot_var('(*right)'))};"]

    with self.hash as f:
      state = self.hasher.state_t.variable("state")
      f.inline_code = [f"{state.definition}; size_t result;",
                       f"assert(target);",
                       f"{self.hasher.create(state)};",
                       f"{self.hasher.update(state, f'(size_t)({self._state_chain(e)})')};",
                       f"if({self._engaged(e)}) {self.hasher.update(state, element.hash(self._slot_var(e)))};",
                       f"result = {self.hasher.hash(state)};",
                       f"{self.hasher.destroy(state)};",
                       f"return result;"]

    with self.method("int", "empty", {"target": self}, brief="Check for the empty state",
      description="""
        Reports whether the optional holds neither a value nor a user state - the
        technically specified empty state.

        @param[in] target the optional to check
        @return non-zero when the optional is in the empty state
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self._is(0)(e)};
      """

    with self.method("int", ("has", "value"), {"target": self}, brief="Check for the engaged state",
      description="""
        Reports whether the optional currently holds an element value. An optional in
        one of the user states holds no value either yet is not empty.

        @param[in] target the optional to check
        @return non-zero when the optional holds an element value
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self._engaged(e)};
      """

    with self.method("int", "state", {"target": self}, brief="Get the current state",
      description="""
        Returns the current state: 0 for the empty state, 1 for the engaged state
        holding the value and the user-defined indices beyond that.

        @param[in] target the optional to inspect
        @return the current state index
      """) as f:
      f.inline_code = f"""
        assert(target);
        return {self._state_chain(e)};
      """

    with self.method(element, "value", {"target": self}, constraint=lambda: element.copyable, brief="Get the held value",
      description="""
        Returns a copy of the held element value. The optional must hold a value.

        @param[in] target the optional to read
        @return the held element value
      """) as f:
      result = f.result.variable("result")
      f.inline_code = f"""
        {result.definition};
        assert(target);
        assert({self._engaged(e)});
        {element.copy(result, self._slot_var(e))};
        return {result};
      """

    with self.method(element.view_type, ("value", "view"), {"target": self}, brief="Get view of the held value",
      description="""
        Returns a constant view of the held element value. The optional must hold a value.

        @param[in] target the optional to inspect
        @return constant view of the held element value
      """) as f:
      f.inline_code = f"""
        assert(target);
        assert({self._engaged(e)});
        return {self._slot_var(e).bind(f.result)};
      """

    with self.method(None, "set", {"target": inout(self), "element": element}, constraint=lambda: element.copyable, brief="Engage with a copy of the element",
      description="""
        Releases the currently held value when present and engages the optional with a
        copy of the given element.

        @param[in,out] target the optional to engage
        @param[in] element the element to copy
      """) as f:
      f.inline_code = f"""
        assert(target);
        if({self._engaged(e)}) {{{destroy_slot};}}
        {element.copy(self._slot_var(e), f.element)};
        {self._mark(1)(e)};
      """

    with self.method(None, "emplace", {"target": inout(self)} | element.constructor_parameters,
      constraint=lambda: element.emplaceable,
      brief="Engage with an element constructed in place",
      description="""
        Releases the currently held value when present and constructs a new element in
        place with the forwarded parameters.

        @param[in,out] target the optional to engage
      """) as f:
      create_args = [getattr(f, name) for name in element.constructor_parameters]
      f.inline_code = f"""
        assert(target);
        if({self._engaged(e)}) {{{destroy_slot};}}
        {element.create(self._slot_var(e), *create_args)};
        {self._mark(1)(e)};
      """

    with self.method(None, "reset", {"target": inout(self)}, brief="Release the value and enter the empty state",
      description="""
        Releases the currently held value when present and brings the optional into the
        empty state.

        @param[in,out] target the optional to reset
      """) as f:
      f.inline_code = f"""
        assert(target);
        if({self._engaged(e)}) {{{destroy_slot};}}
        {self._mark(0)(e)};
      """

    if self.nstates > 2:
      with self.method(None, ("set", "state"), {"target": inout(self), "state": "int"}, brief="Transition to one of the named states",
        description="""
          Brings the optional into the given state releasing the currently held value when
          present. Marking the engaged state requires the optional to already hold a value.

          @param[in,out] target the optional to transition
          @param[in] state the state to enter - 0 for empty, 1 for the engaged state, beyond that the user-defined states
        """) as f:
        marks = [f"if({f.state} == {s}) {{{self._mark(s)(e)};}}" for s in range(self.nstates) if s != 1]
        f.inline_code = f"""
          assert(target);
          assert({f.state} >= 0 && {f.state} < {self.nstates});
          if({f.state} == 1) {{
            assert({self._engaged(e)});
          }} else if({self._engaged(e)}) {{
            {{{destroy_slot};}}
          }}
          {' '.join(marks)}
        """

  # Marks the target storage with the state the source storage is in
  def _mark_states_from(self, target_e, source_e):
    marks = [f"if({self._is(s)(source_e)}) {{{self._mark(s)(target_e)};}}" for s in range(self.nstates) if s != 1]
    return f"{' '.join(marks)} else {{{self._mark(1)(target_e)};}}"

  # Renders the state index of the storage as a C expression
  def _state_chain(self, e):
    chain = [f"{self._is(s)(e)} ? {s} : " for s in range(self.nstates) if s != 1]
    return f"({''.join(chain)}1)"

  def _slot_var(self, e):
    return self.element.variable(self._slot(e))

  @property
  def constructible(self):
    return True

  @property
  def destructible(self):
    return True

  @property
  def copyable(self):
    return self.element.copyable

  @property
  def comparable(self):
    return self.element.comparable

  @property
  def orderable(self):
    return self.element.orderable

  @property
  def hashable(self):
    return self.element.hashable