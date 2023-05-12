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
      dependencies << Module::DEFINITIONS << DEFINITIONS
      references << self.class.seeder
    end

    def render_interface(stream)
      super
      stream << %{
        #ifndef AUTOC_SEED
          #define _AUTOC_RANDOMIZE_SEED
          #define AUTOC_SEED _autoc_seed /**< @brief Statically initialized (random) seed value */
          AUTOC_EXTERN autoc_seed_t _autoc_seed; /**< @private */
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
          autoc_seed_t _autoc_seed = 1;
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

    DEFINITIONS = Code.new interface: %{
      #include <stddef.h>
      typedef size_t autoc_seed_t;
    }

  end # Seed


  class Seeder

    include Singleton

    include Entity

    def initialize = dependencies << Seed::DEFINITIONS

    def next = 'autoc_seeder_next()'

    def render_interface(stream)
      super
      stream << %{
        /**
          @brief Default seeder built upon a system timer
        */
        AUTOC_EXTERN autoc_seed_t autoc_seeder_next(void);
      }
    end

    def render_implementation(stream)
      super
      stream << %{
        #include <time.h>
        autoc_seed_t autoc_seeder_next(void) {
          #if defined(__POCC__)
            /* Pelles C check comes first as it might set _MSC_VER as well */
            unsigned r;
            _rand_s(&r);
            return r;
          #elif defined(_MSC_VER)
            unsigned r;
            rand_s(&r);
            return r;
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


end