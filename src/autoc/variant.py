import autoc.std as std
from autoc.hash import XorRot
from autoc.core import out, _type
from autoc.core import Composite, _StructRenderer


#
class Variant(_StructRenderer, Composite):

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
      f.inline_code = self._destroy_active(target)

    with self.equal as f:
      left = f"({f.left.bind(self)})"
      right = f"({f.right.bind(self)})"
      code = [f"if({left}.tag != {right}.tag) return 0;"]
      code.append(f"switch({left}.tag) {{")
      for index, (name, type) in enumerate(self.alternatives.items()):
        code.append(f"case {index}: return {type.equal(type.variable(f"{left}.value.{name}"), type.variable(f"{right}.value.{name}"))};")
      code.append("default: return 1; /* both empty */")
      code.append("}")
      f.inline_code = code

    with self.copy as f:
      target = f"({f.target.bind(self)})"
      source = f"({f.source.bind(self)})"
      code = [f"assert({f.target});", f"assert({f.source});", self._destroy_active(target), f"{target}.tag = {source}.tag;", f"switch({source}.tag) {{"]
      for index, (name, type) in enumerate(self.alternatives.items()):
        code.append(f"case {index}: {{{type.copy(type.variable(f"{target}.value.{name}"), type.variable(f"{source}.value.{name}"))};}} break;")
      code.append("}")
      f.inline_code = code

    with self.move as f:
      target = f"({f.target.bind(self)})"
      source = f"({f.source.bind(self)})"
      code = [f"assert({f.target});", f"assert({f.source});", self._destroy_active(target), f"{target}.tag = {source}.tag;", f"switch({source}.tag) {{"]
      for index, (name, type) in enumerate(self.alternatives.items()):
        code.append(f"case {index}: {{{type.move(type.variable(f"{target}.value.{name}"), type.variable(f"{source}.value.{name}"))};}} break;")
      code.append("}")
      f.inline_code = code

    with self.hash as f:
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
      f.inline_code = code

    with self.method("int", ("is", "empty"), {"target": self}, visibility=self.visibility) as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"return {target}.tag == -1;"

    for index, (name, type) in enumerate(self.alternatives.items()):
      self._add_predicate(name, index)
      self._add_reader(type, name, index)
      self._add_view(type, name, index)
      self._add_writer(type, name, index)

  def _add_predicate(self, name, index):
    with self.method("int", ("is", name), {"target": self}, visibility=self.visibility) as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"return {target}.tag == {index};"

  def _add_reader(self, type, name, index):
    with self.method(type, name, {"target": self}, attribute=("get", name), visibility=self.visibility, constraint=lambda: type.copyable) as f:
      result = f.result.variable("result")
      target = f"({f.target.bind(self)})"
      f.inline_code = f"""
        {result.definition};
        assert({target}.tag == {index});
        {type.copy(result, type.variable(f"{target}.value.{name}"))};
        return {result};
      """

  def _add_view(self, type, name, index):
    with self.method(type.view_type, (name, "view"), {"target": self}, attribute=("get", name, "view"), visibility=self.visibility) as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"""
        assert({target}.tag == {index});
        return {type.variable(f"{target}.value.{name}").bind(f.result)};
      """

  def _add_writer(self, type, name, index):
    with self.method(None, ("set", name), {"target": out(self), "value": type}, visibility=self.visibility, constraint=lambda: type.copyable) as f:
      target = f"({f.target.bind(self)})"
      f.inline_code = f"""
        {self._destroy_active(target)};
        {target}.tag = {index};
        {type.copy(type.variable(f"{target}.value.{name}"), "value")};
      """

  def _render_struct(self, stream):
    super()._render_struct(stream)
    if self.public:
      stream.append("/** @public */\n")
    stream.append(f"typedef struct {self.name} {self.name};\n")
    if self.public:
      stream.append("/** @public */\n")
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
  def hashable(self):
    return all(type.hashable for type in self.alternatives.values())

  @property
  def orderable(self):
    return False