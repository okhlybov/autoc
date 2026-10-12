from autoc.core import _AliasRenderer
from autoc.optionals import Optional


# The intrusive optional: the states are encoded as sentinel element values supplied
# by the user, with the engaged state being any value matching no sentinel. Exactly
# like the intrusive hash containers this trades value space for representation size.
class Option(_AliasRenderer, Optional):

  brief = "Optional value with the states encoded as sentinel element values"

  def __init__(self, name, element, is_empty, mark_empty, *args, user_states={}, **kwargs):
    super().__init__(name, element, *args, **kwargs)
    self._emitters = {0: (is_empty, mark_empty)}
    for state, (is_state, mark_state) in dict(user_states).items():
      state = int(state)
      if state < 2:
        raise ValueError(f"user states are indexed from 2 upwards, got {state}")
      self._emitters[state] = (is_state, mark_state)
    self.nstates = max(self._emitters) + 1

  def _is(self, state):
    if state == 1:
      return lambda e: self._engaged(e)
    is_state, _ = self._emitters[state]
    return is_state

  def _mark(self, state):
    if state == 1:
      # Holding a real element value IS the engaged state - the element was just put
      # in place by the caller so there is nothing to mark
      return lambda e: str()
    _, mark_state = self._emitters[state]
    return mark_state

  def _slot(self, e):
    # The element storage is the whole value of the intrusive optional
    return e

  def render_declarations(self, stream, header):
    super().render_declarations(stream, header)
    if header:
      stream.append(f"typedef {self.element} {self.name};\n")
