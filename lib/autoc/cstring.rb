# frozen_string_literal: true


require 'autoc/ranges'
require 'autoc/sequential'
require 'autoc/association'


module AutoC


  # Value type string wrapper of the plain C string
  class CString < Association

    include STD

    include Sequential

    def default_constructible? = false

    def range = @range ||= Range.new(self, visibility: visibility, parallel: @parallel)

    def initialize(type = :CString, char = :char, parallel: nil, **kws)
      super(type, char, :size_t, **kws)
      dependencies << STRING_H
      @parallel = parallel
    end

    def rvalue = @rv ||= Value.new(self)
  
    def lvalue = @lv ||= Value.new(self, reference: true)
  
    def const_rvalue = @crv ||= Value.new(self, constant: true)
  
    def const_lvalue = @clv ||= Value.new(self, reference: true, constant: true)

    def render_interface(stream)
      if public?
        stream << %{
          /**
            #{defgroup}

            @brief Value type wrapper of the plain C string

            This type represents a (paper thin) wrapper around the plain C string (char *) with proper value semantics.

            @since 2.0
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef #{element.lvalue} #{signature};
      }
    end

    def storage(target) = target # Return C pointer to contiguous storage

    def render_forward_declarations(stream)
      stream << %{
        #include <stdio.h>
        #include <malloc.h>
        #include <stdarg.h>
        /* overridable internal buffer size (in chars, not bytes) for *sprintf() operations */
        #ifndef AUTOC_BUFFER_SIZE
          #define AUTOC_BUFFER_SIZE 1024
        #endif
      }
      super
    end

    def type_tag = "#{signature}<#{element}>"

  private

    def configure
      super
      method(:void, :create, { target: lvalue, source: const_rvalue }, instance: :custom_create, constraint:-> { custom_constructible? }).configure do
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
          *target = #{memory.allocate(element, 'size+1', atomic: true)}; assert(*target);
          memcpy(*target, source, size*sizeof(#{element}));
          (*target)[size] = '\\0';
        }
      end
      method(:int, :create_format, { target: lvalue, format: const_rvalue }, variadic: true ).configure do
        code %{
          int r;
          va_list args;
          #if defined(HAVE_VSNPRINTF) || __STDC_VERSION__ >= 199901L || __cplusplus > 199711L || (defined(_MSC_VER) && _MSC_VER >= 1900) || defined(__POCC__)
            va_start(args, format);
            r = vsnprintf(NULL, 0, format, args);
            va_end(args);
            if(r < 0) return 0;
            *target = #{memory.allocate(element, 'r+1', atomic: true)}; assert(*target);
            va_start(args, format);
            r = vsnprintf(*target, r+1, format, args);
            va_end(args);
            return r >= 0;
          #else
            #if defined(_MSC_VER)
              #pragma message("WARNING: this code employs bare sprintf() with preallocated temporary buffer of AUTOC_BUFFER_SIZE chars; expect execution bail outs upon exceeding this limit")
            #else
              #warning("this code employs bare sprintf() with preallocated temporary buffer of AUTOC_BUFFER_SIZE chars; expect execution bail outs upon exceeding this limit")
            #endif
            #{element.lvalue} t;
            va_start(args, format);
            t = #{memory.allocate(element, :AUTOC_BUFFER_SIZE, atomic: true)}; assert(t);
            r = vsprintf(t, format, args);
            if(r >= 0) {
              if(r > AUTOC_BUFFER_SIZE-1) {
                /*
                  the output spilled out of the preallocated buffer -
                  perfer to bail out right away rather than to get likely heap corruption
                */
                abort();
              }
              /* prefer precision over performance and make a copy instead of returning a (possibly excessive) buffer */
              #{default_create.(target, :t)};
            }
            /* FIXME handle the case of simultaneous (r < 0 && buffer overrun) */
            #{memory.free(:t)};
            va_end(args);
            return r >= 0;
          #endif
        }
        header %{
          @brief Create formatted string

          @param[out] target string to be created
          @param[in] format format template
          @param[in] ... format parameters

          @result non-zero value on successful construction and zero value otherwise

          This function employs a standard C function from the s*printf() family to create new formatted string.

          @note No `*target` is modified on function failure.

          @since 2.0
        }
      end
      destroy.configure do
        inline_code %{
          assert(target);
          #{memory.free('*target')};
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
        code %{
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
      find_first.configure do
        inline_code %{
          assert(target);
          return strchr(target, value);
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