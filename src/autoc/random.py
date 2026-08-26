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
      AUTOC_EXTERN unsigned _autoc_seed;
      /** @internal */
      AUTOC_EXTERN
        void
      #if defined(__POCC__)
        __cdecl
      #endif
      _autoc_randomize_seed(void);
    """, implementation="""
      unsigned _autoc_seed = 1;
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
      void _autoc_randomize_seed() {
        #if defined(__cplusplus) &&  __cplusplus >= 201103L
          _autoc_seed = std::random_device()();
        #elif defined(__POCC__)
          /* Pelles C check comes first as it might define _MSC_VER as well */
          _rand_s(&_autoc_seed);
        #elif defined(_MSC_VER) && !(defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER)) /* Intel compilers define _MSC_VER on Windows yet their CRTs lack rand_s() */
          rand_s(&_autoc_seed);
        #elif _POSIX_C_SOURCE >= 199309L
          struct timespec ts;
          clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
          _autoc_seed = _autoc_hash(ts.tv_nsec ^ getpid());
        #else
          _autoc_seed = _autoc_hash(time(NULL) ^ getpid() ^ clock());
        #endif
      }
    """, dependencies=(autoc.core._linkage_code, std.stdlib_h, hash))
    self.seed = "_autoc_seed"