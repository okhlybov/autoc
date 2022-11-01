# frozen_string_literal: true


require 'autoc/container'
require 'autoc/range'
require 'autoc/stdc'


module AutoC


  # Value type string based on plain C string
  class CString < ContiguousContainer

    include Container::Sequential

    def default_constructible? = false
    def custom_constructible? = true

    def initialize(type = :CString, visibility: :public)
      super(type, STDC::CHAR, visibility:)
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
          @brief Value type string wrapper around the plain C null-terminated #{element} string
          TODO
        */
      }
      stream << %{
        /**
          #{ingroup}
          @brief Managed C string value
          TODO
        */
        typedef #{element.ptr_type} #{type};
      }
    end

    def configure
      super
      def_method :void, :create, { self: type, source: const_type }, refs: 1, instance: :custom_create do
        inline_code %{
          size_t size;
          assert(self);
          assert(source);
          size = strlen(source);
          *self = malloc((size+1)*sizeof(#{element})); assert(*self);
          memcpy(*self, source, size*sizeof(#{element}));
          (*self)[size] = '\\0';
        }
      end
      ###
        get.refs = 0
        set.refs = 0
        view.refs = 0
        valid_index.refs = 0
      ###
        destroy.inline_code %{
          assert(self);
          free(*self);
        }
      ###
        size.refs = 0
        size.inline_code %{
          assert(self);
          return strlen(self);
        }
      ###
        empty.refs = 0
        empty.inline_code %{
          assert(self);
          return *self == '\\0';
        }
      ###
        equal.refs = 0
        equal.inline_code %{
          assert(self);
          assert(other);
          return strcmp(self, other) == 0;
        }
      ###
        hash_code.refs = 0
        hash_code.inline_code %{
          /* djb2 algorithm: http://www.cse.yorku.ca/~oz/hash.html */
          size_t c;
          size_t hash;
          #{element.ptr_type} s;
          assert(self);
          hash = 5381;
          s = self;
          while((c = *s++)) hash = hash*33 ^ c;
          return hash;
        }
      ###
        compare.refs = 0
        compare.inline_code %{
          assert(self);
          assert(other);
          return strcmp(self, other);
        }
      ###
        copy.refs = 1
        copy.inline_code %{
          assert(self);
          assert(source);
          #{destroy('*self')};
          #{custom_create('*self', :source)};
        }
    end

    # @private
    # Required by the contigious range type to gain direct access to the object's storage
    def storage_ptr(iterable) = iterable

  end # CString

  CString::Range = Range::Contiguous


end