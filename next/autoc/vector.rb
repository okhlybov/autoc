# frozen_string_literal: true


require 'autoc/container'
require 'autoc/range'


module AutoC


  # Generator for the vector container type.
  class Vector < Container

    include Container::Hashable

    def initialize(type, element, visibility = :public)
      super
      @range = Range.new(self, visibility)
      dependencies << range
      @custom_create = function(self, :create_size, 1, { self: type, size: :size_t }, :void) if self.element.default_constructible?
      [default_create, @size, @empty].each(&:inline!)
      @compare = nil # Don't know how to order the vectors
    end

    def canonic_tag = "Vector<#{element.type}>"

    def composite_interface_declarations(stream)
      stream << %$
        /**
          #{defgroup}
          @brief Resizable vector of elements of type #{element.type}

          #{type} is a container that encapsulates dynamic size array of values of type #{element.type}.

          It is a contiguous sequence direct access container where elements can be directly referenced by an integer index belonging to the [0, @ref #{@size}) range.

          For iteration over the vector elements refer to @ref #{range.type}.

          @see C++ [std::vector<T>](https://en.cppreference.com/w/cpp/container/vector)

          @since 2.0
        */
        /**
          #{ingroup}
          @brief Opaque structure holding state of the vector
          @since 2.0
        */
        typedef struct {
          #{element.ptr_type} elements; /**< @private */
          size_t element_count; /**< @private */
        } #{type};
      $
      super
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        #{define(default_create)} {
          assert(self);
          self->element_count = 0;
          self->elements = NULL;
        }
        #{define(@size)} {
          assert(self);
          return self->element_count;
        }
        #{define(@empty)} {
          assert(self);
          return #{size}(self) == 0;
        }
        /**
          #{ingroup}
          @brief Check for position index validity

          @param[in] self vector to check position for
          @param[in] position position index to check for validity
          @return non-zero if `position` is valid (i.e. falls within [0,size) range) and zero otherwise

          The function checks whether `position` falls within [0,size) range.

          @note This function should be used to do explicit bounds checking prior accessing/setting
            the vector's element (see @ref #{get}, @ref #{view}, @ref #{set})
            as the respective functions skip this test for performance reasons.

          @since 2.0
        */
        #{define} int #{check_position}(#{const_ptr_type} self, size_t position) {
          assert(self);
          return position < #{size}(self);
        }
        /**
          #{ingroup}
          @brief Get a view of the element at specified position

          @param[in] self vector to access element from
          @param[in] position position to access element at
          @return a view of element at `position`

          This function is used to get a constant reference (in form the C pointer) to the value contained in `self` at specified position (`return &self[position]`).
          Refer to @ref #{get} to get an independent copy of the element.

          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).

          @note `position` must be valid (see @ref #{check_position}).

          @since 2.0
         */
        #{define} #{element.const_ptr_type} #{view}(#{const_ptr_type} self, size_t position) {
          assert(self);
          assert(#{check_position}(self, position));
          return &(self->elements[position]);
        }
      $
      stream << %$
        /**
          #{ingroup}
          @brief Create a new vector of specified size

          @param[out] self vector to be initialized
          @param[in] size size of new vector

          Each new vector's element is initialized with the respective default constructor.

          This function requires the element type to be *default constructible* (i.e. to have a well-defined parameterless constructor).

          @note Previous contents of `*self` is overwritten.

          @since 2.0
        */
        #{declare(custom_create)};
      $ if custom_constructible?
      stream << %$
        /**
          #{ingroup}
          @brief Create and initialize a new vector of specified size

          @param[out] self vector to be initialized
          @param[in] size size of new vector
          @param[in] value value to initialize the vector with

          Each new vector's element is set to a *copy* of the specified value.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Previous contents of `*self` is overwritten.

          @since 2.0
        */
        #{declare} void #{create_set}(#{ptr_type} self, size_t size, #{element.const_type} value);
      $ if element.copyable?
      stream << %$
        /**
          #{ingroup}
          @brief Resize vector

          @param[in,out] self vector to be resized
          @param[in] new_size new size for the vector

          This function reallocates and transfers all elements from original storage to a new one without preforming a copy operation.

          If new size is gerater than old one (the vector expansion operation), extra elements are initialized with the respective default constructor.

          If new size is smaller the old one (the vector shrinking operation), excessive elements are destroyed with respective destructor.

          This function requires the element type to be *default constructible* (i.e. to have a well-defined parameterless constructor).

          @since 2.0
        */
        #{declare} void #{resize}(#{ptr_type} self, size_t new_size);
      $ if element.default_constructible?
      stream << %$
        /**
          #{ingroup}
          @brief Get an element at specified position

          @param[in] self vector to get element from
          @param[in] position position to get element at
          @return a *copy* of element at `position`

          This function is used to get a *copy* of the value contained in `self` at specified position (`return self[position]`).
          Refer to @ref #{view} to get a view of the element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note `position` must be valid (see @ref #{check_position}).

          @since 2.0
        */
        #{define} #{element.type} #{get}(#{const_ptr_type} self, size_t position) {
          #{element.type} value;
          #{element.const_ptr_type} p = #{view(:self, :position)};
          #{element.copy(:value, '*p')};
          return value;
        }
        /**
          #{ingroup}
          @brief Set an element at specified position

          @param[in] self vector to put element into
          @param[in] position position to put element at
          @param[in] value value to put

          This function is used to set the value in `self` at specified position (`self[position] = value`) to a *copy* of the specified value
          displacing previous value which is destroyed with respective destructor.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note `position` must be valid (see @ref #{check_position}).

          @since 2.0
       */
        #{define} void #{set}(#{ptr_type} self, size_t position, #{element.const_type} value) {
          assert(self);
          assert(#{check_position}(self, position));
          #{element.destroy('self->elements[position]') if element.destructible?};
          #{element.copy('self->elements[position]', :value)};
        }
      $ if element.copyable?
      stream << %$
        /**
          #{ingroup}
          @brief Perform an in-place sorting of the elements

          @param[in] self vector to sort the elements of
          @param[in] direction greater than zero for ascending sort otherwise perform descending sort

          The function performs sorting of the array.

          This function requires the element type to be *orderable* (i.e. to have a well-defined ordering function).

          @since 2.0
        */
        #{declare} void #{sort}(#{ptr_type} self, int direction);
      $ if element.orderable?
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
        #{define} void #{create_set}(#{type}* self, size_t size, #{element.const_type} value) {
          size_t index;
          assert(self);
          #{allocate}(self, size);
          for(index = 0; index < size; ++index) {
            #{element.copy('self->elements[index]', :value)};
          }
        }
      $ if element.copyable?
      stream << %$
        #{define(copy)} {
          size_t index, size;
          assert(self);
          assert(source);
          #{allocate}(self, size = #{size}(source));
          for(index = 0; index < size; ++index) {
            #{element.copy('self->elements[index]', 'source->elements[index]')};
          }
        }
      $ if copyable?
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
        #{define} void #{sort}(#{type}* self, int direction) {
          typedef int (*F)(const void*, const void*);
          assert(self);
          qsort(self->elements, #{size}(self), sizeof(#{element.type}), direction > 0 ? (F)#{ascend} : (F)#{descend});
        }
      $ if element.orderable?
    end


    class Vector::Range < Range::RandomAccess

      def initialize(*args)
        super
        [custom_create, @empty, @length, @view, @save, @pop_front, @front_view, @pop_back, @back_view, @front, @back, @get].each(&:inline!)
      end

      def composite_interface_declarations(stream)
        stream << %$
          /**
            #{defgroup}
            @ingroup #{iterable.type}

            @brief #{canonic_desc}

            This range implements the @ref #{archetype} archetype.

            @see @ref Range

            @since 2.0
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the vector's range
            @since 2.0
          */
          typedef struct {
            #{iterable.const_ptr_type} iterable; /**< @private */
            size_t front_position /**< @private */, back_position; /**< @private */
          } #{type};
        $
        super
      end

      def composite_interface_definitions(stream)
        super
        stream << %$
          #{define(custom_create)} {
            assert(self);
            assert(iterable);
            self->iterable = iterable;
            self->front_position = 0;
            self->back_position = #{iterable.size}(iterable)-1;
          }
          #{define(@length)} {
            assert(self);
            return #{@empty}(self) ? 0 : self->back_position - self->front_position + 1;
          }
          #{define(@empty)} {
            assert(self);
            return !(
              self->front_position <= self->back_position &&
              self->front_position <  self->iterable->element_count &&
              self->back_position  <  self->iterable->element_count
            );
          }
          #{define(@save)} {
            assert(self);
            assert(origin);
            *self = *origin;
          }
          #{define(@pop_front)} {
            assert(!#{@empty}(self));
            ++self->front_position;
          }
          #{define(@pop_back)} {
            assert(!#{@empty}(self));
            --self->back_position; /* This relies on wrapping of unsigned integer used as an index, e.g. (0-1) --> max(size_t) */
          }
          #{define(@front_view)} {
            assert(!#{@empty}(self));
            return #{iterable.view('self->iterable', 'self->front_position')};
          }
          #{define(@back_view)} {
            assert(!#{@empty}(self));
            return #{iterable.view('self->iterable', 'self->back_position')};
          }
          #{define(@view)} {
            assert(self);
            return #{iterable.view('self->iterable', 'self->front_position + position')};
          }
        $
        stream << %$
          #{define(@get)} {
            assert(self);
            return #{iterable.get('self->iterable', 'self->front_position + position')};
          }
        $ if iterable.element.copyable?
      end
    end


  end


end