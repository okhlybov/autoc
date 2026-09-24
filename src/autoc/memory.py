import functools
import autoc.core
import autoc.std as std
from autoc.core import Type
from autoc.module import Code


_allocate_code = Code(
  dependencies=(std.stdlib_h, std.assert_h, autoc.core._linkage_code),
  interface="""
    /** @private */
    AUTOC_EXTERN void* _autoc_malloc(size_t size);
    /** @private */
    AUTOC_EXTERN void* _autoc_calloc(size_t count, size_t size);
  """,
  implementation="""
    void* _autoc_malloc(size_t size) {
      void* ptr = malloc(size);
      if(!ptr && size > 0) {
        assert(0 && "malloc() returned NULL");
        abort();
      }
      return ptr;
    }
    void* _autoc_calloc(size_t count, size_t size) {
      void* ptr = calloc(count, size);
      if(!ptr && count*size > 0) {
        assert(0 && "calloc() returned NULL");
        abort();
      }
      return ptr;
    }
  """
)


# Generic C malloc()+free() memory manager
@functools.cache
class Manager(Code):
  
  def __init__(self, *args, **kws):
    super().__init__(*args, dependencies=(std.stdlib_h, _allocate_code), **kws)
    
  def allocate(self, element, count=1, zero=False, cast=None):
    if isinstance(element, Type):
      type = element
      size = f"sizeof({type})"
    else:
      type = None
      size = element
    if zero:
      code = f"_autoc_calloc({count}, {size})"
    else:
      code = f"_autoc_malloc({size})" if count == 1 else f"_autoc_malloc({count}*{size})"
    if not cast and type:
      cast = type
    return f"({cast}*){code}" if cast else code
    
  def free(self, ptr):
    return f"free({ptr})"