# frozen_string_literal: true


require 'autoc/composite'


module AutoC


  # @abstract
  class Range < Composite

    attr_reader :iterable

    def initialize(iterable, visibility)
      super(Once.new { iterable.decorate_identifier(:range) }, visibility)
      @iterable = iterable
      @custom_create = function(self, :create, 2, { self: type, iterable: iterable.const_type }, :void)
      @default_create = @destroy = @copy = @move = @equal = @compare = @code = nil
      dependencies << iterable << Doc
    end

    def canonic_tag = "#{iterable.canonic_tag}::Range"

    def canonic_desc = "Range (iterator) for the iterable container #{iterable.canonic_tag}"

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
          @brief Create a new range for the specified iterable

          @param[out] self range to be initialized
          @param[in] iterable container to iterate over

          This function creates a range to iterate over all iterable's elements.

          @note Previous contents of `*self` is overwritten.

          @see #{iterable.get_range}

          @since 2.0
        */
        #{declare(custom_create)};
        /**
          @brief Return new range iterator for the specified iterable

          @param[in] iterable container to iterate over
          @return new initialized range

          This function returns a new range created by @ref #{custom_create}.
          It is intended to be used within the ***for(;;)*** statement as follows

          @code{.c}
          for(#{type} r = #{iterable.get_range}(&it); !#{empty}(&r); #{pop_front}(&r)) { ... }
          @endcode

          where `it` is the iterable to iterate over and `r` is a locally-scoped range bound to it.

          @since 2.0
        */
        #{define} #{type} #{iterable.get_range}(#{iterable.const_ptr_type} iterable) {
          #{type} r;
          assert(iterable);
          #{custom_create}(&r, iterable);
          return r;
        }
      $
    end
  end


  #
  class Range::Input < Range

    private def archetype = :InputRange

    def initialize(iterable, visibility)
      super
      @empty = function(self, :empty, 1, { self: const_type }, :int)
      @pop_front = function(self, :pop_front, 1, { self: type }, :void)
      @front_view = function(self, :front_view, 1, { self: const_type }, iterable.element.const_ptr_type)
      @front = function(self, :front, 1, { self: const_type }, iterable.element.type)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
          @brief Check for range emptiness

          @param[in] self range to check
          @return non-zero value if the range is not empty or zero value otherwise

          An empty range is the range for which there are to accessible elements left.
          This specifically means that any calls to the element retrieval and position change functions
          (@ref #{@front}, @ref #{@front_view}, @ref #{@pop_front} et al.) are invalid for empty ranges.

          @since 2.0
        */
        #{declare(@empty)};
        /**
          @brief Advance front position to the next existing element

          @param[in] self range to advance front position for

          This function is used to get to the next element in the range.

          @note Prior calling this function one must ensure that the range is not empty (see @ref #{@empty}).
          Advancing position of a range that is already empty results in undefined behaviour.

          @since 2.0
        */
        #{declare(@pop_front)};
        /**
          @brief Get a view of the front element

          @param[in] self range to retrieve element from
          @return a view of an element at the range's front position

          This function is used to get a constant reference (in form of the C pointer) to the value contained in the iterable container at the range's front position.
          Refer to @ref #{@front} to get an independent copy of that element.
  
          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).
  
          @note Range must not be empty (see @ref #{@empty}).

          @since 2.0
        */
        #{declare(@front_view)};
      $
      stream << %$
        /**
          @brief Get a copy of the front element

          @param[in] self range to retrieve element from
          @return a *copy* of element at the range's front position

          This function is used to get a *copy* of the value contained in the iterable container at the range's front position.
          Refer to @ref #{@front_view} to get a view of the element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Range must not be empty (see @ref #{@empty}).

          @since 2.0
        */
        #{define(@front)} {
          #{iterable.element.type} result;
          assert(!#{empty}(self));
          #{iterable.element.const_ptr_type} e = #{@front_view}(self);
          #{iterable.element.copy(:result, '*e')};
          return result;
        }
      $ if iterable.element.copyable?
    end

  end


  #
  class Range::Forward < Range::Input

    private def archetype = :ForwardRange

    def initialize(iterable, visibility)
      super
      @save = function(self, :save, 2, { self: type, origin: const_type }, :void)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
          @brief Capture a snapshot of the range's state

          @param[out] self new range
          @param[in] origin exising range

          This is effectively a range cloning operation.
          
          After cloning the two ranges themselves become independent, they do however share the iterable container.

          @note Previous contents of `*self` is overwritten.

          @since 2.0
        */
        #{declare(@save)};
      $
    end

  end


  #
  class Range::Bidirectional < Range::Forward

    private def archetype = :BidirectionalRange

    def initialize(iterable, visibility)
      super
      @pop_back = function(self, :pop_back, 1, { self: type }, :void)
      @back_view = function(self, :back_view, 1, { self: const_type }, iterable.element.const_ptr_type)
      @back = function(self, :back, 1, { self: const_type }, iterable.element.type)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
          @brief Rewind back position to the previous existing element

          @param[in] self range to rewind back position for

          This function is used to get to the previous element in the range.

          @note Prior calling this function one must ensure that the range is not empty (see @ref #{@empty}).
          Advancing position of a range that is already empty results in undefined behaviour.

          @since 2.0
        */
        #{declare(@pop_back)};
        /**
          @brief Get a view of the back element

          @param[in] self range to retrieve element from
          @return a view of an element at the range's back position

          This function is used to get a constant reference (in form of the C pointer) to the value contained in the iterable container at the range's back position.
          Refer to @ref #{@back} to get an independent copy of that element.

          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).

          @note Range must not be empty (see @ref #{@empty}).

          @since 2.0
        */
        #{declare(@back_view)};
      $
      stream << %$
          /**
          @brief Get a copy of the back element

          @param[in] self range to retrieve element from
          @return a *copy* of element at the range's back position

          This function is used to get a *copy* of the value contained in the iterable container at the range's back position.
          Refer to @ref #{@back_view} to get a view of the element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Range must not be empty (see @ref #{@empty}).

          @since 2.0
        */
         #{define(@back)} {
          #{iterable.element.type} result;
          assert(!#{empty}(self));
          #{iterable.element.const_ptr_type} e = #{@back_view}(self);
          #{iterable.element.copy(:result, '*e')};
          return result;
        }
      $ if iterable.element.copyable?
    end

  end


  #
  class Range::RandomAccess < Range::Bidirectional

    private def archetype = :RandomAccessRange

    def initialize(iterable, visibility)
      super
      @length = function(self, :length, 1, { self: const_type }, :size_t)
      @view = function(self, :view, 1, { self: const_type, position: :size_t }, iterable.element.const_ptr_type)
      @get = function(self, :get, 1, { self: const_type, position: :size_t }, iterable.element.type)
    end

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
          @brief Get a number of elements in the range

          @param[in] self range to query
          @return a number of elements

          This function returns a number of elements between the range's front and back positions inclusively.
          As a consequence, the result changes with every invocation of position change functions (@ref #{@pop_front}, @ref #{@pop_back}),
          so be careful not to cache this value.

          For empty range this function returns 0.

          @since 2.0
        */
        #{declare(@length)};
        /**
          @brief Get a view of the specific element

          @param[in] self range to retrieve element from
          @return a view of an element at the range's back position

          This function is used to get a constant reference (in form of the C pointer) to the value contained in the iterable container at the specific position.
          Refer to @ref #{@get} to get an independent copy of that element.

          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).

          @note The specified `position` is required to be within the [0, @ref #{@length}) range.

          @see @ref #{@length}
  
          @since 2.0
        */
        #{declare(@view)};
      $
      stream << %$
        /**
          @brief Get a copy of the specific element

          @param[in] self range to retrieve element from
          @param[in] position an element position
          @return a *copy* of element at the range `position`

          This function is used to get a *copy* of the value contained in the iterable container at the specific position.
          Refer to @ref #{@view} to get a view of the element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note The specified `position` is required to be within the [0, @ref #{@length}) range.

          @see @ref #{@length}

          @since 2.0
        */
        #{declare(@get)};
      $ if iterable.element.copyable?
    end
  end


  Range::Doc = Code.new interface: %$
    /**
      @page Range

      @brief Generalization of the iterator

      A range is a means of traversing through the container's contents in which it is similar to the iterator.

      Current implementation is loosely modeled after the [D language ranges](https://dlang.org/phobos/std_range.html).

      Note that current ranges' implementation is fairly basic lacking iterable alteration, thread safety etc.
      On the other hand, all currently implemented ranges are the simple value types which do not require explicit
      copying/destruction thus making life slightly easier.
      Therefore they can be passed out in/out the functions as is - just watch out the dangers of passing the
      iterable values they are bound to.

      A sample code involving iteration over the contents of a hypothetical `List` iterable value is shown below.

      @code{.c}
      List list;
      ...
      for(ListRange r = ListGetRange(&list); !ListRangeEmpty(&r); ListRangePopFront(&r)) {
        ... = ListRangeFront(&r);
      }
      @endcode

      Currently implemented range archetypes:
      @subpage InputRange
      @subpage ForwardRange
      @subpage BidirectionalRange
      @subpage RandomAccessRange

      @since 2.0

      @page InputRange

      @brief Basic unidirectional range

      An input range is a @ref Range which sports a single direction of traversing the elements.

      @since 2.0

      @page ForwardRange

      @brief Unidirectional range with checkpoint

      A forward range is an @ref InputRange which also allows to make a snapshot of the current range's state for possible fallback.

      @since 2.0

      @page BidirectionalRange

      @brief Basic bidirectional range

      A bidirectional range is a @ref ForwardRange which can also be traversed backwards.

      @since 2.0

      @page RandomAccessRange

      @brief Bidirectional range with indexed access to specific elements

      A random access range is a @ref BidirectionalRange which is also capable of accessing the elements directly using index.

      @since 2.0
    */
  $


end