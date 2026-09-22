import autoc.std as std
from autoc.hash import XorRot
from autoc.core import out, _type
from autoc.core import Composite, _StructRenderer


#
class Variant(_StructRenderer, Composite):

  brief = "Union container holding a single typed value from a predefined type set"
  
  def __init__(self, name, alternatives, *args, hasher=XorRot(), dependencies=(), **kws):
    super().__init__(name, *args, dependencies=(*dependencies, std.assert_h, hasher), **kws)
    self.alternatives = {str(name): _type(type) for name, type in alternatives.items()}
    self.hasher = hasher
    self.dependencies.update(self.alternatives.values())

  def _destroy_active(self, target):
    # Generates the code destroying the currently held alternative of the value referenced by the target expression.
    # The empty state (negative tag) matches no case so destroying an empty variant is a no-op.
    cases = []
    for index, (name, type) in enumerate(self.alternatives.items()):
      if type.destructible:
        cases.append(f"case {index}: {{{type.destroy(type.variable(f"{target}.value.{name}"))};}} break;")
    return f"switch({target}.tag) {{{" ".join(cases)}}}" if cases else str()

  def __setup__(self):
    super().__setup__()

    with self.create as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"{target}.tag = -1;"

    with self.destroy as f:
      target = f"({f.target.bind(self)})"
      f.code = self._destroy_active(target)

    with self.equal as f:
      def _equal(f=f):
        left = f"({f.left.bind(self)})"
        right = f"({f.right.bind(self)})"
        code = [f"if({left}.tag != {right}.tag) return 0;"]
        code.append(f"switch({left}.tag) {{")
        for index, (name, type) in enumerate(self.alternatives.items()):
          code.append(f"case {index}: return {type.equal(type.variable(f"{left}.value.{name}"), type.variable(f"{right}.value.{name}"))};")
        code.append("default: return 1; /* both empty */")
        code.append("}")
        return str().join([str(x) for x in code])
      f.code = _equal

    with self.copy as f:
      def _copy(f=f):
        target = f"({f.target.bind(self)})"
        source = f"({f.source.bind(self)})"
        code = [f"assert({f.target});", f"assert({f.source});", f"{target}.tag = {source}.tag;", f"switch({source}.tag) {{"]
        for index, (name, type) in enumerate(self.alternatives.items()):
          code.append(f"case {index}: {{{type.copy(type.variable(f"{target}.value.{name}"), type.variable(f"{source}.value.{name}"))};}} break;")
        code.append("}")
        return str().join([str(x) for x in code])
      f.code = _copy

    with self.move as f:
      def _move(f=f):
        # Built lazily: the alternatives of the non movable variants have their moves inactive
        target = f"({f.target.bind(self)})"
        source = f"({f.source.bind(self)})"
        code = [f"assert({f.target});", f"assert({f.source});", f"{target}.tag = {source}.tag;", f"switch({source}.tag) {{"]
        for index, (name, type) in enumerate(self.alternatives.items()):
          code.append(f"case {index}: {{{type.move(type.variable(f"{target}.value.{name}"), type.variable(f"{source}.value.{name}"))};}} break;")
        code.append("}")
        code.append(f"{self.create(f.source)}; /* the moved-from variant is left in the empty state */")
        return str().join([str(x) for x in code])
      f.code = _move

    with self.hash as f:
      def _hash(f=f):
        target = f"({f.target.bind(self)})"
        state = self.hasher.state_t.variable("state")
        code = [f"{state.definition}; size_t result; {self.hasher.create(state)};", f"assert({f.target});"]
        code.append(self.hasher.update(state, f"(size_t){target}.tag"))
        code.append(";")
        code.append(f"switch({target}.tag) {{")
        for index, (name, type) in enumerate(self.alternatives.items()):
          code.append(f"case {index}: {{{self.hasher.update(state, type.hash(type.variable(f"{target}.value.{name}")))};}} break;")
        code.append("}")
        code.append(f"result = {self.hasher.hash(state)}; {self.hasher.destroy(state)}; return result;")
        return str().join([str(x) for x in code])
      f.code = _hash

    with self.method("int", ("is", "empty"), {"target": self}, visibility=self.visibility, brief="Check if the variant holds no value",
      description="""
        Reports whether the variant was never assigned a value - the freshly created
        variant holds no alternative until the first `set` call.

        @param[in] target the variant to test
        @return non-zero if the variant holds no value
      """) as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"return {target}.tag == -1;"

    for index, (name, type) in enumerate(self.alternatives.items()):
      self._add_predicate(name, index)
      self._add_reader(type, name, index)
      self._add_view(type, name, index)
      self._add_writer(type, name, index)

  def _add_predicate(self, name, index):
    with self.method("int", ("is", name), {"target": self}, visibility=self.visibility, brief=f"Check if the variant holds the {name} value",
      description=f"""
        Reports whether the variant currently holds the {name} alternative - the cheap
        tag check to guard the `{name}` reads.

        @param[in] target the variant to test
        @return non-zero if the variant currently holds the {name} alternative
      """) as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"return {target}.tag == {index};"

  def _add_reader(self, type, name, index):
    with self.method(type, name, {"target": self}, attribute=("get", name), visibility=self.visibility, constraint=lambda: type.copyable, brief=f"Get the {name} value",
      description=f"""
        Returns an owned copy of the value held as the {name} alternative. The variant must
        actually hold that alternative - check with `is_{name}` first since a mismatch is
        a contract violation.

        @param[in] target the variant to read - must hold the {name} alternative
        @return a copy of the value held as the {name} alternative
      """) as f:
      result = f.result.variable("result")
      target = f"({f.target.bind(self)})"
      f.inline_code = f"""
        {result.definition};
        assert({target}.tag == {index});
        {type.copy(result, type.variable(f"{target}.value.{name}"))};
        return {result};
      """

  def _add_view(self, type, name, index):
    with self.method(type.view_type, (name, "view"), {"target": self}, attribute=("get", name, "view"), visibility=self.visibility, brief=f"Get view of the {name} value",
      description=f"""
        Returns a pointer to the value held as the {name} alternative without copying it.
        The view is valid while the variant keeps holding the {name} alternative - any
        `set` call destroying it invalidates the view.

        @param[in] target the variant to read - must hold the {name} alternative
        @return a constant view of the value held as the {name} alternative, valid while the variant keeps that alternative
      """) as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"""
        assert({target}.tag == {index});
        return {type.variable(f"{target}.value.{name}").bind(f.result)};
      """

  def _add_writer(self, type, name, index):
    with self.method(None, ("set", name), {"target": out(self), "value": type}, visibility=self.visibility, constraint=lambda: type.copyable, brief=f"Set the {name} value",
      description=f"""
        Stores the value as the {name} alternative - the alternative the variant held
        before is destroyed first since a variant holds exactly one value at a time.

        @param[out] target the variant to update
        @param[in] value the value to store as the {name} alternative - the alternative previously held is destroyed
      """) as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"""
        {self._destroy_active(target)};
        {target}.tag = {index};
        {type.copy(type.variable(f"{target}.value.{name}"), "value")};
      """

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"struct {self.name} {{\n")
    stream.append("int tag; /**< @private */\n")
    stream.append("union {\n")
    for name, type in self.alternatives.items():
      stream.append(f"{type} {name};\n")
    stream.append("} value; /**< @private */\n")
    stream.append("};\n")

  @property
  def constructible(self):
    # A variant is always constructible - its create initializes the empty state without touching any alternative
    return True

  @property
  def destructible(self):
    return any(type.destructible for type in self.alternatives.values())

  @property
  def comparable(self):
    return all(type.comparable for type in self.alternatives.values())

  @property
  def copyable(self):
    return all(type.copyable for type in self.alternatives.values())

  @property
  def moveable(self):
    return all(type.moveable for type in self.alternatives.values())

  @property
  def swappable(self):
    return all(type.swappable for type in self.alternatives.values())

  @property
  def hashable(self):
    return all(type.hashable for type in self.alternatives.values())

  @property
  def orderable(self):
    return False