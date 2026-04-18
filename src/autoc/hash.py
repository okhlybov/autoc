from autoc.module import Code
import autoc.std as std
import autoc.random
from autoc.core import out, Macro


seeder = autoc.random.RandomSeeder()


class _IncrementalHasher(Code):
  
  def __init__(self, seeder=None, dependencies=[], **kws):
    self.seeder = seeder if seeder else autoc.hash.seeder
    super().__init__(dependencies=[*dependencies, self.seeder], **kws)
    self.state_t = std.size_t
    self.create = Macro(None, {"state": out(self.state_t)}, lambda state: f"{state} = {self.seeder.seed}")
    self.destroy = Macro(None, {"state": out(self.state_t)}, lambda source: str())
    self.hash = Macro(std.size_t, {"state": self.state_t}, lambda state: state)
    # self.update =

  
# Incremental xor+shift hasher for ordered data types
class XorShift(_IncrementalHasher):

  def __init__(self, dependencies=[], **kws):
    super().__init__(dependencies=[*dependencies, XorShift.__rotr])
    self.update = Macro(None, {"state": out(self.state_t), "hash": std.size_t}, lambda state, hash: f"{state} ^= _autoc_rotr({hash})")
    
  __rotr = autoc.module.Code(dependencies=[std.limits_h, std.size_t, std.linkage], definitions=f"""
      AUTOC_STATIC_INLINE
      size_t _autoc_rotr(size_t value) {{
        return (value << 1) | (value >> (sizeof(size_t)*CHAR_BIT - 1));
      }}
    """)
    
    
# Incremental xor hasher for unordered data types
class Xor(_IncrementalHasher):

  def __init__(self, **kws):
    super().__init__(**kws)
    self.update = Macro(None, {"state": out(self.state_t), "hash": std.size_t}, lambda state, hash: f"{state} ^= {hash}")