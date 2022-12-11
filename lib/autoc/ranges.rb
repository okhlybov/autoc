# frozen_string_literal: true


require 'autoc/std'
require 'autoc/composite'


module AutoC


  using STD::Coercions


  # @abstract
  class Range < Composite

    attr_reader :iterable

    def default_constructible? = false
    def destructible? = false
    def comparable? = false
    def orderable? = false
    def copyable? = false

    def to_value = @v ||= Value.new(self)

    def initialize(iterable, visibility:)
      super(iterable.identifier(visibility == :internal ? :_R : :range), visibility:)
      dependencies << (@iterable = iterable) << INFO
    end

    def tag = @tag ||= "#{iterable.tag}::Range"

  private

    alias _iterable iterable # Use _iterable.() within method bodies as it is shadowed by the commonly used iterable function parameter

    def configure
      super
      method(:void, :create, { range: lvalue, iterable: iterable.const_rvalue }, instance: :custom_create).configure do
        header %{
          @brief Create a new range for the specified iterable

          @param[out] range range to be initialized
          @param[in] iterable container to iterate over

          This function creates a range to iterate over all iterable's elements.

          @note Previous contents of `*range` is overwritten.

          @see #{new}

          @since 2.0
        }
      end
      method(self, :new, { iterable: iterable.const_rvalue }).configure do
        dependencies << custom_create
        header %{
          @brief Return new range iterator for the specified container

          @param[in] iterable container to iterate over
          @return new initialized range

          This function returns a new range created by @ref #{custom_create}.
          It is intended to be used within the ***for(;;)*** statement as follows

          @code{.c}
          for(#{type} r = #{new}(&it); !#{empty}(&r); #{pop_front}(&r)) { ... }
          @endcode

          where `it` is the iterable to iterate over and `r` is a locally-scoped range bound to it.

          @since 2.0
        }
        inline_code %{
          #{type} r;
          assert(iterable);
          #{custom_create.(:r, iterable)};
          return r;
        }
      end
    end

  end # Range


  # @abstract
  class InputRange < Range

  private

    def configure
      super
      method(:int, :empty, { range: const_rvalue }).configure do
        header %{
          @brief Check for range emptiness

          @param[in] range range to check
          @return non-zero value if the range is not empty or zero value otherwise

          An empty range is the range for which there are to accessible elements left.
          This specifically means that any calls to the element retrieval and position change functions
          (@ref #{take_front}, @ref #{view_front}, @ref #{pop_front} et al.) are invalid for empty ranges.

          @since 2.0
        }
      end
      method(:void, :pop_front, { range: rvalue }).configure do
        header %{
          @brief Advance front position to the next existing element

          @param[in] range range to advance front position for

          This function is used to get to the next element in the range.

          @note Prior calling this function one must ensure that the range is not empty (see @ref #{empty}).
          Advancing position of a range that is already empty results in undefined behaviour.

          @since 2.0
        }
      end
      method(iterable.element.const_lvalue, :view_front, { range: const_rvalue }).configure do
        header %{
          @brief Get a view of the front element

          @param[in] range range to retrieve element from
          @return a view of an element at the range's front position

          This function is used to get a constant reference (in form of the C pointer) to the value contained in the iterable container at the range's front position.
          Refer to @ref #{take_front} to get an independent copy of that element.
  
          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).
  
          @note Range must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      method(iterable.element, :take_front, { range: const_rvalue }, constraint:-> { iterable.element.copyable? }).configure do
        dependencies << empty << view_front
        inline_code %{
          #{iterable.element} result;
          #{iterable.element.const_lvalue} e;
          assert(!#{empty.(range)});
          e = #{view_front.(range)};
          #{iterable.element.copy.(:result, '*e')};
          return result;
        }
        header %{
          @brief Get a copy of the front element

          @param[in] range range to retrieve element from
          @return a *copy* of element at the range's front position

          This function is used to get a *copy* of the value contained in the iterable container at the range's front position.
          Refer to @ref #{view_front} to get a view of the element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Range must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
    end

  end # InputRange


  # @abstract
  class ForwardRange < InputRange

    def copyable? = true

  private

    def configure
      super
      copy.configure do
        inline_code %{
          assert(target);
          assert(source);
          *target = *source;
        }
      end
    end

  end # ForwardRange


  # @abstract
  class BidirectionalRange < ForwardRange

    private

    def configure
      super
      method(:void, :pop_back, { range: rvalue }).configure do
        header %{
          @brief Rewind back position to the previous existing element

          @param[in] range range to rewind back position for

          This function is used to get to the previous element in the range.

          @note Prior calling this function one must ensure that the range is not empty (see @ref #{empty}).
          Rewinding position of a range that is already empty results in undefined behaviour.

          @since 2.0
        }
      end
      method(iterable.element.const_lvalue, :view_back, { range: const_rvalue }).configure do
        header %{
          @brief Get a view of the back element

          @param[in] range range to retrieve element from
          @return a view of an element at the range's back position

          This function is used to get a constant reference (in form of the C pointer) to the value contained in the iterable container at the range's back position.
          Refer to @ref #{take_back} to get an independent copy of that element.
  
          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).
  
          @note Range must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      method(iterable.element, :take_back, { range: const_rvalue }, constraint:-> { iterable.element.copyable? }).configure do
        dependencies << empty << view_back
        inline_code %{
          #{iterable.element} result;
          #{iterable.element.const_lvalue} e;
          assert(!#{empty.(range)});
          e = #{view_back.(range)};
          #{iterable.element.copy.(:result, '*e')};
          return result;
        }
        header %{
          @brief Get a copy of the back element

          @param[in] range range to retrieve element from
          @return a *copy* of element at the range's back position

          This function is used to get a *copy* of the value contained in the iterable container at the range's front position.
          Refer to @ref #{view_back} to get a view of the element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Range must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
    end

  end # BidirectionalRange


  # @abstract
  class DirectAccessRange < BidirectionalRange

  private

    def configure
      super
      method(:size_t, :size, { range: const_rvalue }).configure do
        header %{
          @brief Get a number of elements in the range

          @param[in] self range to query
          @return a number of elements

          This function returns a number of elements between the range's front and back positions inclusively.
          As a consequence, the result changes with every invocation of position change functions (@ref #{pop_front}, @ref #{pop_back}),
          so be careful not to cache this value.

          For empty range this function returns 0.

          @since 2.0
        }
      end
      method(iterable.element.const_lvalue, :view, { range: const_rvalue, index: :size_t.const_rvalue }).configure do
        header %{
          @brief Get view of the specific element

          @param[in] range range to view element from
          @param[in] index position to access element at
          @return a view of element at `index`

          This function is used to get a constant reference (in form of the C pointer) to the value contained in the range at the specific position.
          Refer to @ref #{get} to get a copy of the element.

          @note The specified `index` is required to be within the [0, @ref #{size}) range.

          @since 2.0
        }
      end
      method(iterable.element, :get, { range: const_rvalue, index: :size_t.const_rvalue }, constraint:-> { iterable.element.copyable? }).configure do
        dependencies << empty << view
        inline_code %{
          #{iterable.element} r;
          #{iterable.element.const_lvalue} e;
          assert(!#{empty.(range)});
          e = #{view.(range, index)};
          #{iterable.element.copy.(:r, '*e')};
          return r;
        }
        header %{
          @brief Get a copy of the specific element

          @param[in] range range to retrieve element from
          @param[in] index position to view element at
          @return a *copy* of element at `index`

          This function is used to get a *copy* of the value contained in the range at the specific position.
          Refer to @ref #{view} to get a view of the element without making an independent copy.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note The specified `position` is required to be within the [0, @ref #{size}) range.

          @since 2.0
        }
      end
    end

  end # DirectAccessRange


  # @abstract
  class ContiguousRange < DirectAccessRange

    def render_interface(stream)
      stream << %{
        /**
          #{defgroup}

          @brief #{tag}
        */
        typedef struct {
          #{iterable.element.lvalue} front; /** @private */
          #{iterable.element.lvalue} back; /** @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      custom_create.configure do
        inline_code %{
          assert(range);
          assert(iterable);
          range->front = #{_iterable.storage(iterable)};
          range->back = #{_iterable.storage(iterable)} + #{_iterable.size.(iterable)};
        }
      end
      empty.configure do
        inline_code %{
          assert(range);
          assert(range->front);
          assert(range->back);
          return range->front > range->back;
        }
      end
      pop_front.configure do
        dependencies << empty
        inline_code %{
          assert(range);
          assert(range->front);
          assert(!#{empty.(range)});
          ++range->front;
        }
      end
      pop_back.configure do
        dependencies << empty
        inline_code %{
          assert(range);
          assert(range->back);
          assert(!#{empty.(range)});
          --range->back;
        }
      end
      view_front.configure do
        dependencies << empty
        inline_code %{
          assert(range);
          assert(range->front);
          assert(!#{empty.(range)});
          return range->front;
        }
      end
      view_back.configure do
        dependencies << empty
        inline_code %{
          assert(range);
          assert(range->back);
          assert(!#{empty.(range)});
          return range->back;
        }
      end
      size.configure do
        dependencies << empty
        inline_code %{
          assert(range);
          assert(range->front);
          assert(range->back);
          return #{empty.(range)} ? 0 : range->back - range->front + 1;
        }
      end
      view.configure do
        dependencies << size
        inline_code %{
          assert(range);
          assert(index < #{size.(range)});
          return range->front + index;
        }
      end
    end

  end # ContiguousRange


  Range::INFO = Code.new interface: %{
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
        ... = ListRangeTakeFront(&r);
      }
      @endcode

      Currently implemented range archetypes:
      @subpage InputRange
      @subpage ForwardRange
      @subpage BidirectionalRange
      @subpage DirectAccessRange

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

      @page DirectAccessRange

      @brief Bidirectional range with indexed access to specific elements

      A random access range is a @ref BidirectionalRange which is also capable of accessing the elements directly using index.

      @since 2.0
    */
  }


end