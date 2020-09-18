require 'singleton'
require 'autoc/module'


module AutoC


  # Basic incremental hasher.
  class Hasher

    include Singleton
    include Module::Entity

    def type
      :size_t
    end

    def create(hasher)
      "#{hasher} = AUTOC_HASHER_SEED"
    end

    def update(hasher, value)
      "#{hasher} = ((#{hasher} << 1) | (#{hasher} >> (sizeof(#{hasher})*CHAR_BIT - 1))) ^ (#{value})"
    end

    def result(hasher)
      hasher
    end

    def destroy(hasher) end

    def interface(stream)
      stream << %$
        #include <limits.h>
        #ifndef AUTOC_HASHER_TRIVIAL_SEED
          #if defined(__GNUC__) || defined(__clang__)
          #else
            #define AUTOC_HASHER_TRIVIAL_SEED
          #endif
        #endif
        #ifdef AUTOC_HASHER_TRIVIAL_SEED
          #define AUTOC_HASHER_SEED 0
        #else
          #include <stddef.h>
          #define AUTOC_HASHER_SEED __autoc_hasher_seed
          extern size_t __autoc_hasher_seed;
        #endif
      $
    end

    def definitions(stream)
      stream << %$
        #ifndef AUTOC_HASHER_TRIVIAL_SEED
          #include <time.h>
          #include <stdlib.h>
          size_t __autoc_hasher_seed;
          #ifdef __cplusplus
            static
          #elif defined(__GNUC__) || defined(__clang__)
            __attribute__((constructor))
          #else
            #warning __autoc_hasher_initialize() wont be called automatically; ensure it is called manually in order to initialize the hasher seed
          #endif
          void __autoc_hasher_initialize() {
            time_t t;
            srand((unsigned)time(&t));
            __autoc_hasher_seed = rand(); /* TODO use rand_s() if available */
          }
          #ifdef __cplusplus
            struct __autoc_hasher {
              __autoc_hasher() {
                __autoc_hasher_initialize();
              }
            };
            static __autoc_hasher __autoc_hasher_instance;
          #endif
        #endif
      $
    end

    @@default = instance
    def self.default; @@default end
    def self.default=(hasher) @@default = hasher end

  end # Hasher


end # AutoC