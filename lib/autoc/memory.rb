# frozen_string_literal: true


require 'singleton'
require 'autoc/type'
require 'autoc/module'


module AutoC


  # Standard C malloc()-based allocator.
  class Allocator

    include Singleton
    include Entity

    def allocate(type, count = 1, zero = false)
      zero ? "(#{type}*)calloc(#{count}, sizeof(#{type}))" : "(#{type}*)malloc((#{count})*sizeof(#{type}))"
    end

    def free(ptr) = "free(#{ptr})"

    def interface_declarations(stream)
      super
      stream << %{
        #include <stdlib.h>
      }
    end

    @@default = instance

    def self.default = @@default

    def self.default=(allocator) @@default = allocator end

  end # Allocator


  # Aligned memory allocator.
  class Allocator::Aligning

    include Singleton
    include Entity

    def initialize = dependencies << Module::DEFINITIONS

    def allocate(type, count = 1, zero = false, alignment = 32)
      zero ? "(#{type}*)_autoc_aligned_calloc(#{count}, sizeof(#{type}), #{alignment})" : "(#{type}*)_autoc_aligned_malloc((#{count})*sizeof(#{type}), #{alignment})"
    end

    def free(ptr) = "_autoc_aligned_free(#{ptr})"

    def interface_definitions(stream)
      super
      stream << %{
        /**
          @brief Aligned memory allocator
        */
        AUTOC_EXTERN void* _autoc_aligned_malloc(size_t size, size_t alignment);
        /**
          @brief Aligned memory allocator with zero initialization
        */
        AUTOC_EXTERN void* _autoc_aligned_calloc(size_t count, size_t size, size_t alignment);
        /**
          @brief Aligned memory deallocator
        */
        AUTOC_EXTERN void _autoc_aligned_free(void* ptr);
      }
    end

    def definitions(stream)
      super
      stream << %{
        #include <malloc.h>
        #include <string.h>
        void* _autoc_aligned_malloc(size_t size, size_t alignment) {
          #if __STDC_VERSION__ >= 201112L
            return aligned_alloc(alignment, size);
          #elif defined(MSC_VER) || defined(__MINGW32__)
            return _aligned_malloc(size, alignment);
          #elif _POSIX_VERSION >= 200112L
            void* ptr;
            return posix_memalign(&ptr, alignment, size) ? NULL : ptr;
          #else
            #error no suitable aligned memory allocation function found
          #endif
        }
        void* _autoc_aligned_calloc(size_t count, size_t size, size_t alignment) {
          const size_t bytes = count*size;
          return memset(_autoc_aligned_malloc(bytes, alignment), 0, bytes);
        }
        void _autoc_aligned_free(void* ptr) {
          #if defined(MSC_VER) || defined(__MINGW32__)
            _aligned_free(ptr);
          #else
            free(ptr);
          #endif
        }
      }
    end

  end # Allocator::Aliging


  # Boehm garbage-collecting allocator.
  class Allocator::BDW

    include Singleton
    include Entity

    def allocate(type, count = 1, zero = false) = "(#{type}*)GC_malloc((#{count})*sizeof(#{type}))"

    def free(ptr) = nil

    def interface_declarations(stream)
      super
      stream << %{
        #include <gc.h>"
      }
    end

  end # BDW

end # AutoC