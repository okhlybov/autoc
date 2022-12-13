# frozen_string_literal: true


require 'autoc/ranges'
require 'autoc/containers'


module AutoC


  # Value type string wrapper around plain C string
  class CString < ContiguousContainer

    def default_constructible? = false

    def range = @range ||= Range.new(self, visibility: visibility, parallel: @parallel)

    def initialize(type = :CString, char = :char, **kws)
      super(type, char, **kws)
    end

    def rvalue = @rv ||= Value.new(self)
  
    def lvalue = @lv ||= Value.new(self, reference: true)
  
    def const_rvalue = @crv ||= Value.new(self, constant: true)
  
    def const_lvalue = @clv ||= Value.new(self, constant: true)

    def render_interface(stream)
      super
      stream << %{
        #include <string.h>
        #include <malloc.h>
        /**
          #{defgroup}

          @brief Value type wrapper around plain C string

          This type represents a (paper thin) wrapper around the plain C string with proper value semantics.

          @since 2.0
        */
        typedef #{element.lvalue} #{signature};
      }
    end

    def storage(target) = target # Return C pointer to contiguous storage

  private

    def configure
      super
      method(:void, :create, { target: lvalue, source: const_rvalue }, instance: :custom_create ).configure do
        header %{
          @brief Create string

          @param[out] target string to be created
          @param[in]  source string to be copied

          This function creates & initializes a new string by making an independent of the source string.
          This specifically means that the supplied source string may be any C string, either const or mutable, including string literal.

          Previous contents of `*target` is overwritten.

          Once constructed, the string is to be destroyed with @ref #{destroy}.

          @since 2.0
        }
        inline_code %{
          size_t size;
          assert(target);
          assert(source);
          size = strlen(source);
          *target = malloc((size+1)*sizeof(#{element})); assert(*target);
          memcpy(*target, source, size*sizeof(#{element}));
          (*target)[size] = '\\0';
        }
      end
      destroy.configure do
        inline_code %{
          assert(target);
          free(*target);
        }
      end
      copy.configure do
        dependencies << custom_create
        inline_code %{
          #{custom_create.(*parameters)};
        }
      end
      get.configure do
        dependencies << check
        inline_code %{
          assert(target);
          assert(#{check.(target, index)});
          return target[index];
        }
      end
      set.configure do
        dependencies << check
        inline_code %{
          assert(target);
          assert(#{check.(target, index)});
          target[index] = value;
        }
      end
      view.configure do
        dependencies << check
        inline_code %{
          assert(target);
          assert(#{check.(target, index)});
          return &target[index];
        }
      end
      equal.configure do
        inline_code %{
          assert(left);
          assert(right);
          return strcmp(left, right) == 0;
        }
      end
      compare.configure do
        inline_code %{
          assert(left);
          assert(right);
          return strcmp(left, right);
        }
      end
      hash_code.configure do
        inline_code %{
          /* djb2 algorithm: http://www.cse.yorku.ca/~oz/hash.html */
          size_t c;
          size_t hash;
          #{element.lvalue} s;
          assert(target);
          hash = 5381;
          s = target;
          while((c = *s++)) hash = hash*33 ^ c;
          return hash;
        }
      end
      contains.configure do
        inline_code %{
          assert(target);
          return strchr(target, value) != NULL;
        }
      end
      check.configure do
        dependencies << size
        inline_code %{
          assert(target);
          return index < #{size.(target)};
        }
      end
      empty.configure do
        inline_code %{
          assert(target);
          return *target == '\\0';
        }
      end
      size.configure do
        inline_code %{
          assert(target);
          return strlen(target);
        }
      end
    end

  end # CString


  CString::Range = ContiguousRange # Range


end