import autoc.module
import autoc.std as std
import autoc.core as core


# Generic xor+shift hasher
class Hasher(autoc.module.Code):

  def __init__(self):
    super().__init__(dependencies=[std.limits_h, std.stddef_h, std.assert_h], interface=f"""
      /** @private */
      static inline size_t _autoc_rcycle(size_t value) {{
        return (value << 1) | (value >> (sizeof(size_t)*CHAR_BIT - 1));
      }}
    """)

  state_t = std.size_t
  create = core.Macro(None, dict(state=state_t), lambda state: f"{state} = 0") # TODO optional seed randomization
  destroy = core.Macro(None, dict(state=state_t), lambda source: str())
  update = core.Macro(None, dict(state=state_t, hash=state_t), lambda state, hash: f"{state} ^= _autoc_rcycle({hash})")
  hash = core.Macro(state_t, dict(state=state_t), lambda state: state)