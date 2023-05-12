require 'singleton'
require 'autoc/std'
require 'autoc/module'
require 'autoc/composite'


module AutoC


  class Seed

    include Singleton

    include Entity

    def self.seeder = @seeder

    def self.seeder=(s) @seeder = s end

    def initialize
      dependencies << Module::DEFINITIONS << Random::DEFINITIONS
      references << self.class.seeder
    end

    def render_interface(stream)
      super
      stream << %{
        #ifndef AUTOC_SEED
          #define _AUTOC_RANDOMIZE_SEED
          #define AUTOC_SEED _autoc_seed /**< @brief Statically initialized (random) seed value */
          AUTOC_EXTERN autoc_random_t _autoc_seed; /**< @private */
        #elif ~(~AUTOC_SEED + 1) == 1 /* if macro value is unspecified on the command line it is implicitly set to 1 */
          #undef AUTOC_SEED
          #define AUTOC_SEED 1
        #endif
      }
    end

    def render_implementation(stream)
      super
      stream << %{
        #ifdef _AUTOC_RANDOMIZE_SEED
          autoc_random_t _autoc_seed = 1;
          #if defined(__cplusplus)
            extern "C" void _autoc_seed_randomize(void);
          #elif defined(__GNUC__) || defined(__clang__) || defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER)
            void _autoc_seed_randomize(void) __attribute__((__constructor__));
          #elif defined(__POCC__)
            #pragma startup _autoc_seed_randomize
          #elif defined(_MSC_VER)
            #pragma message("WARNING: _autoc_seed_randomize() will not be called automatically; either call it manually or compile this source as C++ in order to actually yield random seed")
          #else
            #warning _autoc_seed_randomize() will not be be called automatically; either call it manually or compile this source as C++ in order to actually yield random seed
          #endif
          #ifdef __POCC__
            #include <stdlib.h>
          #endif
          void
          #ifdef __POCC__
            __cdecl
          #endif
          _autoc_seed_randomize(void) {
            _autoc_seed = #{self.class.seeder.next};
          }
          #ifdef __cplusplus
            static struct _hasher {
              _hasher() {_autoc_seed_randomize();}
            } _hasher;
          #endif

        #endif
      }
    end

  end # Seed


  module Random
    DEFINITIONS = Code.new interface: %{
      typedef unsigned int autoc_random_t;
    }
  end


  class Seeder

    include Singleton

    include Entity

    def initialize = dependencies << Random::DEFINITIONS

    def next = 'autoc_seeder_next()'

    def render_interface(stream)
      super
      stream << %{
        /**
          @brief Default random value seeder

          The exact quality depends on the target platform.
          Its purpose is to be useful when no specific properties for the seeds are required.

          As a consequence is not meant to be cryptographically viable.

          @since 2.1
        */
        AUTOC_EXTERN autoc_random_t autoc_seeder_next(void);
      }
    end

    def render_implementation(stream)
      super
      stream << %{
        #if __cplusplus >= 201103L
          #include <random>
        #endif
        #include <time.h>
        autoc_random_t autoc_seeder_next(void) {
          #if defined(__POCC__)
            /* Pelles C check comes first as it might set _MSC_VER as well */
            unsigned r;
            _rand_s(&r);
            return r;
          #elif defined(_MSC_VER)
            unsigned r;
            rand_s(&r);
            return r;
          #elif __cplusplus >= 201103L
            return std::random_device()();
          #elif _POSIX_C_SOURCE >= 199309L
            struct timespec ts;
            clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
            srand(ts.tv_nsec);
            return rand();
          #else
            srand(time(NULL));
            return rand();
          #endif
        }
      }
    end

  end # Seeder


  Seed.seeder = Seeder.instance


  class PRNG
  
    include Singleton

    include Entity

    def initialize = dependencies << Module::DEFINITIONS << Random::DEFINITIONS

    def to_s = :autoc_random_t

    def render_interface(stream)
      super
      stream << %{
        /**
          @brief Default pseudo-random number generator

          @since 2.1
        */
        AUTOC_EXTERN autoc_random_t autoc_prng_next(autoc_random_t* state);
      }
    end

    def render_implementation(stream)
      super
      # https://en.wikipedia.org/wiki/Lehmer_random_number_generator
      stream << %{
        autoc_random_t autoc_prng_next(autoc_random_t* state) {
          /* basic Lehmer PRNG */
          #if __cplusplus >= 201103L || __STDC_VERSION__ >= 199901L || defined(HAVE_LONG_LONG)
            /* suitable for machines with types wider than autoc_random_t avaliable */
            typedef unsigned long long int ull_t;
            ull_t product = (ull_t)*state * 48271;
            ull_t x = (product & 0x7fffffff) + (product >> 31);
            x = (x & 0x7fffffff) + (x >> 31);
            return *state = x;
          #else
            /* fallback implementation for any 32-bit machine */
            const autoc_random_t A = 48271;
            autoc_random_t low  = (*state & 0x7fff) * A;
            autoc_random_t high = (*state >> 15)    * A;
            autoc_random_t x = low + ((high & 0xffff) << 15) + (high >> 16);
            x = (x & 0x7fffffff) + (x >> 31);
            return *state = x;
          #endif
        }
      }
    end

  end # PRNG


end