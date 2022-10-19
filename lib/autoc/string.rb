# frozen_string_literal: true


require 'autoc/composite'
require 'autoc/stdc'


module AutoC

  # Value type string based on plain C string
  class CString < Composite

    def default_constructible? = false
    def custom_constructible? = true

    def initialize(type = :CString, visibility: :public)
      super(type, visibility:)
      @char = STDC::CHAR
    end
  
    def composite_interface_declarations(stream)
      super
      stream << %{
        #include <assert.h>
        #include <stddef.h>
        #include <stdlib.h>
        #include <string.h>
        /**
          #{defgroup}
          @brief Value type string wrapper around the plain C null-terminated #{@char} string
        */
      }
      stream << %{
        /**
          #{ingroup}
          @brief Managed C string value
        */
        typedef #{@char.ptr_type} #{type};
      }
    end

    def configure
      super
      def_method :void, :create, { self: type, source: @char.const_ptr_type }, instance: :custom_create do
        inline_code %{
          size_t size;
          assert(self);
          assert(source);
          size = strlen(source);
          *self = malloc((size+1)*sizeof(#{@char})); assert(*self);
          memcpy(*self, source, size*sizeof(#{@char}));
          (*self)[size] = '\\0';
        }
      end
      def_method :size_t, :size, { self: const_type } do
        inline_code %{
          assert(self);
          return strlen(*self);
        }
      end
      equal.inline_code %{
        assert(self);
        assert(other);
        return strcmp(*self, *other) == 0;
      }
      hash_code.inline_code %{
        /* djb2 algorithm: http://www.cse.yorku.ca/~oz/hash.html */
        size_t hash;
        assert(self);
        hash = 5381;
        if(*self) {
          size_t c;
          #{@char.ptr_type} str = *self;
          while((c = *str++)) hash = hash*33 ^ c;
        }
        return hash;
      }
      compare.inline_code %{
        assert(self);
        assert(other);
        return strcmp(*self, *other);
      }
      copy.inline_code %{
        assert(source);
        #{destroy('*self')};
        #{custom_create('*self', '*source')};
      }
      destroy.inline_code %{
        assert(self);
        free(*self);
      }
    end
end

end