import functools
import autoc.core
import autoc.std
import autoc.module


# Generic C malloc()+free() memory manager
@functools.cache
class Manager(autoc.module.Code):
  
  def __init__(self):
    super().__init__(dependencies=[autoc.std.malloc_h])
    
  def allocate(self, element, count=1, zero=False, cast=None):
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
    if not cast and type:
      cast = type
    return f"({cast}*){code}" if cast else code
    
  def free(self, ptr):
    return f"free({ptr})"