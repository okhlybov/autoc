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

    def create(hasher) = "#{hasher} = AUTOC_SEED"

    def destroy(hasher) = nil

    def update(hasher, value) = "#{hasher} = ((#{hasher} << 1) | (#{hasher} >> (sizeof(#{hasher})*CHAR_BIT - 1))) ^ (#{value})"

    def result(hasher) = hasher
    
    def initialize = dependencies << STD::LIMITS_H << STD::STDDEF_H << AutoC::Random.seed

  end # Hasher


  XXHASH_H = AutoC::Code.new interface: %{
    #define XXH_INLINE_ALL
    #include "xxhash.h"
  }


  class Hashers

    include Singleton

    include AutoC::Entity

    def initialize = dependencies << Module::DEFINITIONS

    def render_interface(stream)
      stream << %{
        /**
          @brief General purpose hasher for int value

          @since 2.1
        */
        AUTOC_INLINE int autoc_hash_int(int key) {
          int c2=0x27d4eb2d;
          key = (key ^ 61) ^ (key >> 16);
          key = key + (key << 3);
          key = key ^ (key >> 4);
          key = key * c2;
          key = key ^ (key >> 15);
          return key;
        }
        /**
          @brief General purpose hasher for long value

          @since 2.1
        */
        AUTOC_INLINE long autoc_hash_long(long key) {
          key = (~key) + (key << 21);
          key = key ^ (key >> 24);
          key = (key + (key << 3)) + (key << 8);
          key = key ^ (key >> 14);
          key = (key + (key << 2)) + (key << 4);
          key = key ^ (key >> 28);
          key = key + (key << 31);
          return key;
        }
      }
    end

  end

end