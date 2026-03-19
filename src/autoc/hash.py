import functools
import autoc.module
import autoc.std as std
from autoc.core import Macro
from autoc.core import out


# Generic xor+shift hasher
@functools.cache
class Hasher(autoc.module.Code):

  def __init__(self):
    super().__init__(dependencies=[std.limits_h, self.state_t, std.definitions], interface=f"""
      /** @private */
      AUTOC_STATIC_INLINE size_t _autoc_rcycle(size_t value) {{
        return (value << 1) | (value >> (sizeof(size_t)*CHAR_BIT - 1));
      }}
    """)

  state_t = std.size_t
  create = Macro(None, {"state": out(state_t)}, lambda state: f"{state} = 0") # TODO optional seed randomization
  destroy = Macro(None, {"state": out(state_t)}, lambda source: str())
  update = Macro(None, {"state": out(state_t), "hash": std.size_t}, lambda state, hash: f"{state} ^= _autoc_rcycle({hash})")
  hash = Macro(std.size_t, {"state": state_t}, lambda state: state)