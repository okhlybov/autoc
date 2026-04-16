from autoc.core import out, inout
import autoc.std as std
import autoc.composite
import autoc.module
import functools


#
class Set(autoc.composite.Collection):
  
  def __setup__(self):
    super().__setup__()
    
    self.put = self.method("int", "put", {"target": inout(self), "element": self.element})

    # TODO more to come


#
ceil_power2 = autoc.module.Code(dependencies=[std.size_t, std.linkage], interface=f"""
  /* @private */
  AUTOC_EXTERN
  size_t _autoc_ceil_power2(size_t value);
""", definitions="""
  size_t _autoc_ceil_power2(size_t value) {
    if(value == 0) return 1;
    value--;
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    value |= value >> 8;
    value |= value >> 16;
    if(sizeof(size_t) >= 8) value |= value >> 32;
    return ++value;
  }
""")