require 'singleton'
require 'autoc/std'
require 'autoc/module'
require 'autoc/randoms'


module AutoC


  # Basic xor-shift incremental hasher
  class Hasher

    include Singleton

    include Entity

    def to_s = :size_t

    def create(hasher) = "#{hasher} = autoc_hash(AUTOC_SEED)"

    def destroy(hasher) = nil

    def update(hasher, value) = "autoc_hash_update(&#{hasher}, #{value})"

    def result(hasher) = hasher
    
    def initialize = dependencies << Hashers.instance << AutoC::Random.seed

  end # Hasher



  class Hashers

    # On size_t: https://pvs-studio.com/en/blog/posts/cpp/a0050/
    # On 32 vs 64 bit: https://pvs-studio.com/en/blog/posts/cpp/a0004/

    include Singleton

    include AutoC::Entity

    def initialize = dependencies << Module::DEFINITIONS << STD::STDDEF_H << STD::LIMITS_H

    def render_interface(stream)
      stream << %{
        #if defined(_WIN64) /* win64 is a special case with all 32-bit integers */ \\
        || INT_MAX < LONG_MAX /* sizeof(int)==4 regardless of the machine word's size (almost?) everywhere whereas long has the machine word size */
          #define _AUTOC_HASHER_64
        #endif
        /**
          @brief General purpose hasher for an integer value

          This function implements the Thomas Wang's mixing algorithms.

          @see http://web.archive.org/web/20071223173210/http://www.concentric.net/~Ttwang/tech/inthash.htm

          @since 2.1
        */
        AUTOC_INLINE size_t autoc_hash(size_t key) {
          #ifdef _AUTOC_HASHER_64
            /* sizeof(size_t) == 8 */
            key = (~key) + (key << 21);
            key = key ^ (key >> 24);
            key = (key + (key << 3)) + (key << 8);
            key = key ^ (key >> 14);
            key = (key + (key << 2)) + (key << 4);
            key = key ^ (key >> 28);
            key = key + (key << 31);
          #else
            /* sizeof(size_t) == 4 */
            key = (key ^ 61) ^ (key >> 16);
            key = key + (key << 3);
            key = key ^ (key >> 4);
            key = key * 0x27d4eb2d;
            key = key ^ (key >> 15);
          #endif
          return key;
        }
        /**
          @brief General purpose hash combinator for incremental hash construction

          This function implements the boost::hash_combine() algorithm.

          @see https://stackoverflow.com/questions/4948780/magic-number-in-boosthash-combine

          @since 2.1
        */
        AUTOC_INLINE void autoc_hash_update(size_t* hash, size_t key) {
          *hash ^= key +
            #ifdef _AUTOC_HASHER_64
              0x9e3779b97f4a7c15
            #else
              0x9e3779b9
            #endif
          + (*hash << 6) + (*hash >> 2);
        }
      }
    end

  end

end