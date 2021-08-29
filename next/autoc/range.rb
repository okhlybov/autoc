require 'autoc/composite'


module AutoC


  #
  class Range < Composite

    attr_reader :iterable

    private def range_type = Once.new { "#{iterable.type}Range" }

    def initialize(iterable)
      super(range_type)
      @iterable = iterable
      @custom_create = function(self, :create, 2, { self: type, iterable: iterable.const_type }, :void)
      @default_create = @destroy = @copy = @move = @equal = @compare = @code = nil
      @initial_dependencies << iterable
    end

    def interface_definitions(stream)
      super
      stream << %$
        /**
        * @brief Create an new range iterator other the specified iterable
        */
        #{declare(@custom_create)};
      $
    end
  end


  #
  class Range::Input < Range

    def initialize(iterable)
      super
      @empty = function(self, :empty, 1, { self: const_type }, :int)
      @pop_front = function(self, :pop_front, 1, { self: type }, :void)
      @front_view = function(self, :front_view, 1, { self: const_type }, iterable.element.const_ptr_type)
      @front = function(self, :front, 1, { self: const_type }, iterable.element.type)
    end

    def interface_definitions(stream)
      super
      stream << %$
        /**
        * @brief Return non-zero if the range is empty (that is there are no elements left) and zero otherwise
        */
        #{declare(@empty)};
        /**
        * @brief Advance current position to the next element
        *
        * There is a valid element at new position as long as @ref #{@empty}() returns zero.
        */
        #{declare(@pop_front)};
        /**
        * @brief Return a view of front element
        *
        * Range must not be empty (refer to @ref #{@empty}()).
        */
        #{declare(@front_view)};
      $
      stream << %$
        /**
        * @brief Return a copy of front element
        *
        * Range must not be empty (refer to @ref #{@empty}()).
        */
        #{declare(@front)};
      $ if iterable.element.copyable?
    end

  end


  #
  class Range::Forward < Range::Input

    def initialize(iterable)
      super
      @save = function(self, :save, 2, { self: type, origin: const_type }, :void)
    end

    def interface_definitions(stream)
      super
      stream << %$
        /**
        * @brief Capture current state of the original range
        */
        #{declare(@save)};
      $
    end

  end


  #
  class Range::Bidirectional < Range::Forward

    def initialize(iterable)
      super
      @pop_back = function(self, :pop_back, 1, { self: type }, :void)
      @back_view = function(self, :back_view, 1, { self: const_type }, iterable.element.const_ptr_type)
      @back = function(self, :back, 1, { self: const_type }, iterable.element.type)
    end

    def interface_definitions(stream)
      super
      stream << %$
        /**
         * @brief Rewind current position to the previous element
         *
         * There is a valid element at new position as long as @ref #{@empty}() returns zero.
         */
        #{declare(@pop_back)};
        /**
         * @brief Return a view of back element
         *
         * Range must not be empty (refer to @ref #{@empty}()).
         */
        #{declare(@back_view)};
      $
      stream << %$
        /**
         * @brief Return a copy of back element
         *
         * Range must not be empty (refer to @ref #{@empty}()).
         */
        #{declare(@back)};
      $ if iterable.element.copyable?
    end

  end


  #
  class Range::RandomAccess < Range::Bidirectional

    def initialize(iterable)
      super
      @length = function(self, :length, 1, { self: const_type }, :size_t)
      @view = function(self, :view, 1, { self: const_type, position: :size_t }, iterable.element.const_ptr_type)
      @get = function(self, :get, 1, { self: const_type, position: :size_t }, iterable.element.type)
    end

    def interface_definitions(stream)
      super
      stream << %$
        /**
        * @brief Return a number of elements in the range
        */
        #{declare(@length)};
        /**
        * @brief Return a view of the element at specified position
        */
        #{declare(@view)};
      $
      stream << %$
        /**
        * @brief Return a copy of the element at specified position
        */
        #{declare(@get)};
      $ if iterable.element.copyable?
    end
  end


end