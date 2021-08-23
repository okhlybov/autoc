require 'autoc/type'
require 'autoc/memory'
require 'autoc/range'


module AutoC


  class Vector < Container

    #
    attr_reader :range

    def initialize(type, element)
      super
      @custom_create = Composite::Function.new(self, :create_size, 1, { self: type, size: :size_t }, :void) if self.element.default_constructible?
      @range = Range.new(self)
      @initial_dependencies << range
    end

    def interface_declarations(stream)
      stream << %$
        /**
         * @defgroup #{type} Resizeable vector of values of type <#{element.type}>
         * @{
         */
        typedef struct {
          #{element.type}* elements;
          size_t element_count;
        } #{type};
      $
      super
      stream << '/** @} */'
    end

    def interface_definitions(stream)
      super
      stream << %$
        /**
         * @addtogroup #{type}
         * @{
         */
        /**
         * @brief Create a new vector of zero size at self
         */
        #{define(default_create)} {
          assert(self);
          self->element_count = 0;
          self->elements = NULL;
        }
        /**
         * @brief Destroy the vector at self along with its elements and free storage
         */
        #{declare(destroy)};
      $
      stream << %$
        /**
         * @brief Create a new vector at self of specified size
         *
         * Each vector's element is initialized with the respective default constructor.
         */
        #{declare(custom_create)};
      $ if custom_constructible?
      stream << %$
        /**
         * @brief Create a new vector of specified size at self
         *
         * Each vector's element is initialized with the specified value.
         */
        #{declare} void #{create_fill}(#{type}* self, size_t size, #{element.const_type} value);
      $ if element.copyable?
      stream << %$
        #include <stddef.h>
        #{define} size_t #{size}(#{const_type}* self) {
          assert(self);
          return self->element_count;
        }
        #{define} int #{within}(#{const_type}* self, size_t index) {
          assert(self);
          return index < #{size}(self);
        }
        #{define} const #{element.type}* #{view}(#{const_type}* self, size_t index) {
          assert(self);
          assert(#{within}(self, index));
          return &(self->elements[index]);
        }
      $
      stream << %$
        /**
         * @brief Resize the vector at self to contain the specified number of elements
         *
         * If the new size is smaller than current size, the excessive elements are destroyed with the element's destructor.
         *
         * If the new size is greater that current size the extra elements are created with the element's default constructor.
         */
        #{declare} void #{resize}(#{type}* self, size_t new_size);
      $ if element.default_constructible?
      stream << %$
        #{declare(copy)};
        #{define} #{element.type} #{get}(#{const_type}* self, size_t index) {
          #{element.type} value;
          #{element.const_type}* p = #{view(:self, :index)};
          #{element.copy(:value, '*p')};
          return value;
        }
        #{define} void #{set}(#{type}* self, size_t index, #{element.const_type} value) {
          assert(self);
          assert(#{within}(self, index));
          #{element.destroy('self->elements[index]') if element.destructible?};
          #{element.copy('self->elements[index]', :value)};
        }
      $ if element.copyable?
      stream << "#{declare} #{equal.declaration};" if comparable?
      stream << "#{declare} void #{sort}(#{type}* self, int direction);" if element.orderable?
      stream << %$/** @} */$
    end

    def definitions(stream)
      super
      stream << %$
        static void #{allocate}(#{type}* self, size_t element_count) {
          assert(self);
          if((self->element_count = element_count) > 0) {
            self->elements = #{memory.allocate(element.type, :element_count)}; assert(self->elements);
          } else {
            self->elements = NULL;
          }
        }
      $
      stream << %$
        #{define(destroy)} {
          assert(self);
      $
      stream << %${
        size_t index, size = #{size}(self);
        for(index = 0; index < size; ++index) #{element.destroy('self->elements[index]')};
      }$ if element.destructible?
      stream << %$
        #{memory.free('self->elements')};
      }$
      stream << %$
        #{define(custom_create)} {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < size; ++index) {
            #{element.default_create('self->elements[index]')};
          }
        }
      $ if custom_constructible?
      stream << %$
        #{define} void #{resize}(#{type}* self, size_t new_size) {
          size_t index, size, from, to;
          assert(self);
          if((size = #{size}(self)) != new_size) {
            #{element.type}* elements = #{memory.allocate(element.type, :new_size)}; assert(elements);
            from = AUTOC_MIN(size, new_size);
            to = AUTOC_MAX(size, new_size);
            for(index = 0; index < from; ++index) {
              elements[index] = self->elements[index];
            }
            if(size > new_size) {
              #{'for(index = from; index < to; ++index)' + element.destroy('self->elements[index]') if element.destructible?};
            } else {
              for(index = from; index < to; ++index) {
                #{element.default_create('elements[index]')};
              }
            }
            #{memory.free('self->elements')};
            self->elements = elements;
            self->element_count = new_size;
          }
        }
      $ if element.default_constructible?
      stream << %$
        #{define} void #{create_fill}(#{type}* self, size_t size, #{element.const_type} value) {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < size; ++index) {
            #{element.copy('self->elements[index]', :value)};
          }
        }
        #{define} #{copy.definition} {
          size_t index, size;
          assert(self);
          assert(source);
          #{destroy}(self);
          #{allocate}(self, size = #{size}(source));
          for(index = 0; index < size; ++index) {
            #{element.copy('self->elements[index]', 'source->elements[index]')};
          }
        }
      $ if element.copyable?
      stream << %$
        #{define(equal)} {
          size_t index, size;
          assert(self);
          assert(other);
          if(#{size}(self) == (size = #{size}(other))) {
            for(index = 0; index < size; ++index) {
              if(!(#{element.equal('self->elements[index]', 'other->elements[index]')})) return 0;
            }
            return 1;
          } else return 0;
        }
      $ if comparable?
      stream << %$
        static int #{ascend}(void* lp_, void* rp_) {
          #{element.const_type}* lp = (#{element.type}*)lp_;
          #{element.const_type}* rp = (#{element.type}*)rp_;
          return #{element.compare('*lp', '*rp')};
        }
        static int #{descend}(void* lp_, void* rp_) {
          return -#{ascend}(lp_, rp_);
        }
        #include <stdlib.h>
        #{define} void #{sort}(#{type}* self, int order) {
          typedef int (*F)(const void*, const void*);
          assert(self);
          qsort(self->elements, #{size}(self), sizeof(#{element.type}), order > 0 ? (F)#{ascend} : (F)#{descend});
        }
      $ if element.orderable?
    end


    class Vector::Range < Range::RandomAccess

      def interface_declarations(stream)
        @declare = :AUTOC_INLINE
        stream << %$
          /**
          * @defgroup #{type} Range iterator for <#{iterable.type}> iterable container
          * @{
          */
          typedef struct {
            #{iterable.const_type}* iterable;
            size_t position;
          } #{type};
        $
        super
        stream << '/** @} */'
      end
  
      def interface_definitions(stream)
        super
        stream << %$
          #{define(custom_create)} {
            assert(self);
            assert(iterable);
            self->iterable = iterable;
            self->position = 0;
          }
          #{define(@size)} {
            assert(self);
            return #{iterable.size}(self->iterable);
          }
          #{define(@empty)} {
            assert(self);
            return self->position < #{size}(self);
          }
          #{define(@save)} {
            assert(self);
            assert(origin);
            *self = *origin;
          }
          #{define(@pop_front)} {
            assert(self);
            ++self->position;
          }
          #{define(@pop_back)} {
            assert(self);
            --self->position;
          }
          #{define(@front_view)} {
            assert(self);
            return #{iterable.view}(self->iterable, self->position);
          }
          #{define(@back_view)} {
            assert(self);
            return #{iterable.view}(self->iterable, self->position);
          }
          #{define(@view)} {
            assert(self);
            return #{iterable.view}(self->iterable, position);
          }
        $
        stream << %$
          #{define(@front)} {
            assert(self);
            return #{iterable.get}(self->iterable, self->position);
          }
          #{define(@back)} {
            assert(self);
            return #{iterable.get}(self->iterable, self->position);
          }
          #{define(@get)} {
            assert(self);
            return #{iterable.get}(self->iterable, position);
          }
        $ if iterable.element.copyable?
      end
  
      def setup_interface_declarations
        @declare = @define = :AUTOC_INLINE
      end

      def setup_interface_definitions
        @declare = @define = :AUTOC_INLINE
      end

    end


  end


end