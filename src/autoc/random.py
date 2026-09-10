import functools
import autoc.core
import autoc.std as std
from autoc.module import Entity, Code


#
@functools.cache
class StaticSeeder(Entity):
  
  def __init__(self, value=0):
    super().__init__()
    self.seed = value
  

#
hash = Code(dependencies=(autoc.core._linkage_code, std.size_t), interface="""
  /** @internal */
  AUTOC_STATIC_INLINE
  size_t _autoc_hash(size_t key) {
    /*
      Thomas Wang's mixing
      http://web.archive.org/web/20071223173210/http://www.concentric.net/~Ttwang/tech/inthash.htm
    */
    if(sizeof(size_t) >= 8) {
      key = (~key) + (key << 21);
      key = key ^ (key >> 24);
      key = (key + (key << 3)) + (key << 8);
      key = key ^ (key >> 14);
      key = (key + (key << 2)) + (key << 4);
      key = key ^ (key >> 28);
      key = key + (key << 31);
    } else {
      key = (key ^ 61) ^ (key >> 16);
      key = key + (key << 3);
      key = key ^ (key >> 4);
      key = key * 0x27d4eb2d;
      key = key ^ (key >> 15);
    }
    return key;  
  }
""")


@functools.cache
class RandomSeeder(Code):

  def __init__(self):
    super().__init__(interface="""
      /** @internal */
      AUTOC_EXTERN size_t _autoc_seed;
      /** @internal */
      AUTOC_EXTERN
        void
      #if defined(__POCC__)
        __cdecl
      #endif
      _autoc_randomize_seed(void);
    """, implementation="""
      size_t _autoc_seed = 1;
      #include <time.h>
      #ifdef _WIN32
        #include <process.h>
      #else
        #include <unistd.h>
      #endif
      #if defined(__cplusplus)
        #if __cplusplus >= 201103L
          #include <random>
        #endif
        static struct _seed {
          _seed() { _autoc_randomize_seed(); }
        } _seed;
      #elif defined(__GNUC__) || defined(__clang__) || defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER)
        void _autoc_randomize_seed(void) __attribute__((__constructor__));
      #elif defined(__PGI) || defined(__NVCOMPILER)
        #pragma init (_autoc_randomize_seed)
      #elif defined(__POCC__)
        #pragma startup _autoc_randomize_seed
      #elif defined(_MSC_VER)
        #pragma section(".CRT$XCU", read)
        __declspec(allocate(".CRT$XCU"))
        void (*my_init)(void) = _autoc_randomize_seed;
      #else
        _Pragma("_autoc_randomize_seed() will not be be called automatically; either call it manually or compile this source as C++ in order to actually yield random seed")
      #endif
      // FIXME review and reconsider the seed generation changes below
      static unsigned _autoc_entropy_word(void) {
        #if defined(__cplusplus) &&  __cplusplus >= 201103L
          return std::random_device()();
        #elif defined(__POCC__)
          /* Pelles C check comes first as it might define _MSC_VER as well */
          unsigned word;
          _rand_s(&word);
          return word;
        #elif defined(_MSC_VER) && !(defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER)) /* Intel compilers define _MSC_VER on Windows yet their CRTs lack rand_s() */
          unsigned word;
          rand_s(&word);
          return word;
        #elif _POSIX_C_SOURCE >= 199309L
          struct timespec ts;
          clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
          return (unsigned)(ts.tv_nsec ^ getpid());
        #else
          return (unsigned)(time(NULL) ^ getpid() ^ clock());
        #endif
      }
      void _autoc_randomize_seed() {
        _autoc_seed = (size_t)_autoc_entropy_word();
        if(sizeof(size_t) > sizeof(unsigned)) {
          _autoc_seed <<= (sizeof(size_t) - sizeof(unsigned))*CHAR_BIT;
          _autoc_seed ^= (size_t)_autoc_entropy_word();
        }
        _autoc_seed = _autoc_hash(_autoc_seed);
      }
    """, dependencies=(autoc.core._linkage_code, std.stdlib_h, std.size_t, std.limits_h, hash))
    self.seed = "_autoc_seed"


#
# Pointer-address-bound pseudo-random priority generator: derives a stable pseudo-random
# size_t value solely from an object address mixed with the per-process seed. The address
# is expected to remain unchanged during the whole lifetime of the object which makes the
# value reusable on demand without any explicit storage. Note that the generator provides
# statistical (not cryptographic) randomization thus a strong hasher is advised
@functools.cache
class Randomizer(Code):

  def __init__(self, dependencies=(), **kws):
    self._entity_t = autoc.core.Indirection("void", constant=True)
    super().__init__(interface=f"""
      /** @internal */
      AUTOC_STATIC_INLINE
      size_t _autoc_random_priority(const void* entity) {{
        return _autoc_hash(_autoc_seed ^ (size_t)entity);
      }}
    """, dependencies=(*dependencies, autoc.core._linkage_code, std.size_t, RandomSeeder(), hash))

  # Entity is either a bare C side expression rendered as is or a typed value
  # of pointer type subjected to the regular indirection calculation
  def priority(self, entity):
    if isinstance(entity, str):
      value = entity
    else:
      value = entity.bind(self._entity_t)
    return f"_autoc_random_priority({value})"