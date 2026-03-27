import functools
import autoc.std
import autoc.module


# Generic C malloc()+free() memory manager
@functools.cache
class Manager(autoc.module.Code):
  
  def __init__(self):
    super().__init__(dependencies=[autoc.std.malloc_h])
    
  def allocate(self, type=None, size=None, count=1, zero=False):
    if not size:
      size = f"sizeof({type})" if type else 1
    if zero:
      xalloc = f"calloc({count}, {size})"
    else:
      xalloc = f"malloc({size})" if count == 1 else f"malloc({count}*{size})"
    return f"({type}*){xalloc}" if type else xalloc
    
  def free(self, ptr):
    return f"free({ptr})"