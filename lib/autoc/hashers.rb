require 'singleton'
require 'autoc/module'


module AutoC


  # Basic xor-shift incremental hasher
  class Hasher

    include Singleton

    include Entity

    def to_s = :size_t

    def create(hasher) = "#{hasher} = AUTOC_HASHER_SEED"

    def destroy(hasher) = nil

    def update(hasher, value) = "#{hasher} = ((#{hasher} << 1) | (#{hasher} >> (sizeof(#{hasher})*CHAR_BIT - 1))) ^ (#{value})"

    def result(hasher) = hasher
    
    def render_forward_declarations(stream)
      stream << %{
        #include <limits.h>
        #include <stddef.h>
        #ifndef AUTOC_HASHER_SEED /* no seed is specified, using randomly generated one */
          #define _AUTOC_RANDOM_SEED
          #define AUTOC_HASHER_SEED _autoc_hasher_seed
          AUTOC_EXTERN size_t _autoc_hasher_seed;
          AUTOC_EXTERN void _autoc_hasher_randomize_seed(); /* invoke default seed randomizer */
        #elif (AUTOC_HASHER_SEED + 0) /* if seed's value is unspecified */
          #undef AUTOC_HASHER_SEED
          #define AUTOC_HASHER_SEED 0 /* set seed's default value */
        #endif
      }
    end

    def render_implementation(stream)
      stream << %{
        #ifdef _AUTOC_RANDOM_SEED
          #include <time.h>
          #include <stdlib.h>
          size_t _autoc_hasher_seed = 0; /* fallback default until _autoc_hasher_randomize_seed() is called */
          #if !defined(__cplusplus) && (defined(__GNUC__) || defined(__clang__))
            __attribute__((__constructor__))
          #else
            #warning _autoc_hasher_randomize_seed() wont be called automatically; call it manually in order to actually yield random seed
          #endif
          void _autoc_hasher_randomize_seed() {
            srand(time(NULL));
            _autoc_hasher_seed = rand();
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