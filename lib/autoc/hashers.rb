require 'singleton'
require 'autoc/std'
require 'autoc/module'


module AutoC


  # Basic xor-shift incremental hasher
  class Hasher

    include STD
    
    include Singleton

    include Entity

    def to_s = :size_t

    def create(hasher) = "#{hasher} = AUTOC_HASHER_SEED"

    def destroy(hasher) = nil

    def update(hasher, value) = "#{hasher} = ((#{hasher} << 1) | (#{hasher} >> (sizeof(#{hasher})*CHAR_BIT - 1))) ^ (#{value})"

    def result(hasher) = hasher
    
    def initialize = dependencies << STDLIB_H

    def render_forward_declarations(stream)
      stream << %{
        #include <limits.h>
        #include <stddef.h>
        #ifndef AUTOC_HASHER_SEED /* no seed is specified, using randomly generated one */
          #define _AUTOC_RANDOMIZE_SEED
          #define AUTOC_HASHER_SEED _autoc_hasher_seed
          AUTOC_EXTERN size_t _autoc_hasher_seed;
          AUTOC_EXTERN void _autoc_hasher_randomize_seed(void); /* invoke default seed randomizer */
        #elif ~(~AUTOC_HASHER_SEED + 1) == 1 /* if macro value is unspecified on the command line it is implicitly set to 1 */
          #undef AUTOC_HASHER_SEED
          #define AUTOC_HASHER_SEED 0 /* set seed's default value */
        #endif
      }
    end

    def render_implementation(stream)
      # Predefined C compiler macros datasheet: https://sourceforge.net/p/predef/wiki/Compilers/
      stream << %{
        #ifdef _AUTOC_RANDOMIZE_SEED
          #include <time.h>
          size_t _autoc_hasher_seed = 0; /* fallback default until _autoc_hasher_randomize_seed() is called */
          #if defined(__cplusplus)
            extern "C" void _autoc_hasher_randomize_seed(void);
          #elif defined(__GNUC__) || defined(__clang__)
            void _autoc_hasher_randomize_seed(void)  __attribute__((__constructor__));
          #elif defined(__POCC__)
            void __cdecl _autoc_hasher_randomize_seed(void);
            #pragma startup _autoc_hasher_randomize_seed
          #elif defined(_MSC_VER)
            #pragma message("WARNING: _autoc_hasher_randomize_seed() will not be called automatically; either call it manually or compile this source as C++ in order to actually yield random seed")
          #else
            #warning _autoc_hasher_randomize_seed() will not be be called automatically; either call it manually or compile this source as C++ in order to actually yield random seed
          #endif
          void _autoc_hasher_randomize_seed(void) {
            #ifdef _MSC_VER
              unsigned r;
              rand_s(&r);
              _autoc_hasher_seed = r;
            #else
              srand(time(NULL));
              _autoc_hasher_seed = rand();
            #endif
          }
          #ifdef __cplusplus
            static struct _hasher {
              _hasher() {_autoc_hasher_randomize_seed();}
            } _hasher;
          #endif
        #endif
      }
    end

  end # Hasher


end