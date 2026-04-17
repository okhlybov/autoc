import functools
import autoc.module
import autoc.std as std
from autoc.core import out, Macro


# Incremental xor+shift hasher for ordered data types
class XorShift(autoc.module.Code):

  state_t = std.size_t
  create = Macro(None, {"state": out(state_t)}, lambda state: f"{state} = 0") # TODO optional seed randomization
  destroy = Macro(None, {"state": out(state_t)}, lambda source: str())
  update = Macro(None, {"state": out(state_t), "hash": std.size_t}, lambda state, hash: f"{state} ^= _autoc_rotr({hash})")
  hash = Macro(std.size_t, {"state": state_t}, lambda state: state)
  
  def __init__(self):
    super().__init__(dependencies=[XorShift.__rotr])
    
  __rotr = autoc.module.Code(dependencies=[std.limits_h, std.size_t, std.linkage], definitions=f"""
      AUTOC_STATIC_INLINE
      size_t _autoc_rotr(size_t value) {{
        return (value << 1) | (value >> (sizeof(size_t)*CHAR_BIT - 1));
      }}
    """)
    
    
# Incremental xor hasher for unordered data types
class Xor(autoc.module.Code):

  state_t = std.size_t
  create = Macro(None, {"state": out(state_t)}, lambda state: f"{state} = 0") # TODO optional seed randomization
  destroy = Macro(None, {"state": out(state_t)}, lambda source: str())
  update = Macro(None, {"state": out(state_t), "hash": std.size_t}, lambda state, hash: f"{state} ^= {hash}")
  hash = Macro(std.size_t, {"state": state_t}, lambda state: state)
  
  def __init__(self):
    super().__init__(dependencies=[std.size_t])