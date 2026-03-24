import functools
import autoc.module
import autoc.std as std
from autoc.core import Pointer


# Generic C malloc()+free() memory manager
@functools.cache
class Manager(autoc.module.Code):
  
  def __init__(self):
    super().__init__(dependencies=[std.malloc_h])
    
  def allocate(self, type=None, count=1, zero=False):
    if type:
      p = Pointer(type)
      return f"({p})calloc({count}, sizeof({type}))" if zero else f"({p})malloc({count}*sizeof({type}))"
    else:
      return f"calloc({count}, 1)" if zero else f"malloc({count})"
    
  def free(self, obj):
    return f"free({obj})"