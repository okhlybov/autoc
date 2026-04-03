import functools
import autoc.core
import autoc.std
import autoc.module


# Generic C malloc()+free() memory manager
@functools.cache
class Manager(autoc.module.Code):
  
  def __init__(self):
    super().__init__(dependencies=[autoc.std.malloc_h])
    
  def allocate(self, element, count=1, zero=False):
    if isinstance(element, autoc.core.Type):
      type = element
      size = f"sizeof({type})"
    else:
      type = None
      size = element
    if zero:
      code = f"calloc({count}, {size})"
    else:
      code = f"malloc({size})" if count == 1 else f"malloc({count}*{size})"
    return f"({type}*){code}" if type else code
    
  def free(self, ptr):
    return f"free({ptr})"