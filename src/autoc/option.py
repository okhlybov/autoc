from autoc.optionals import Optional
from autoc.core import _StructRenderer


# The plain optional: the state is kept in an integer tag stored alongside the value
class Option(_StructRenderer, Optional):

  brief = "Optional value holding either an element or a state tag"

  def __init__(self, name, element, *args, states=2, **kwargs):
    super().__init__(name, element, *args, **kwargs)
    self.nstates = int(states)
    if self.nstates < 2:
      raise ValueError(f"an optional needs at least the empty and engaged states, got {self.nstates}")

  def _is(self, state):
    return lambda e: f"{e}.tag == {state}"

  def _mark(self, state):
    return lambda e: f"{e}.tag = {state}"

  def _slot(self, e):
    return f"{e}.value"

  def _render_struct(self, stream, header):
    super()._render_struct(stream, header)
    stream.append(f"""
      struct {self.name} {{
        {self.element} value; /**< @private */
        int tag; /**< @private */
      }};
    """)
