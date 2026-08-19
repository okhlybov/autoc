import functools
import autoc2.std as std
from autoc2.core import Type
from autoc.module import Code


# Generic C malloc()+free() memory manager
@functools.cache
class Manager(Code):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, dependencies=(std.stdlib_h,), **kws)
    
  def allocate(self, element, count=1, zero=False, cast=None):
    if isinstance(element, Type):
      type = element
      size = f"sizeof({type})"
    else:
      type = None
      size = element
    if zero:
      code = f"calloc({count}, {size})"
    else:
      code = f"malloc({size})" if count == 1 else f"malloc({count}*{size})"
    if not cast and type:
      cast = type
    return f"({cast}*){code}" if cast else code
    
  def free(self, ptr):
    return f"free({ptr})"