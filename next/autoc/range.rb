require 'autoc/type'


module AutoC


  #
  class Range < Composite


    def type = @type ||= "#{@iterable.type}Range"

    attr_reader :iterable

    def initialize(iterable)
      @iterable = iterable
      super(nil)
      @custom_create = Composite::Function.new(self, :create, 2, { self: type, iterable: iterable.const_type }, :void)
      @default_create = @destroy = @copy = @move = @equal = @compare = @code = nil
      @initial_dependencies << iterable
    end

    def interface_declarations(stream)
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
      @empty = Composite::Function.new(self, :empty, 1, { self: const_type }, :int)
      @pop_front = Composite::Function.new(self, :pop_front, 1, { self: type }, :void)
      @front_view = Composite::Function.new(self, :front_view, 1, { self: const_type }, iterable.element.const_ptr_type)
      @front = Composite::Function.new(self, :front, 1, { self: const_type }, iterable.element.type)
    end

    def interface_declarations(stream)
      super
      stream << %$
        /**
        * @brief Return true if there it no element left in the range
        */
        #{declare(@empty)};
        /**
        * @brief
        */
        #{declare(@pop_front)};
        /**
        * @brief
        */
        #{declare(@front_view)};
      $
      stream << %$
        /**
        * @brief
        */
        #{declare(@front)};
      $ if iterable.element.copyable?
    end

  end


  #
  class Range::Forward < Range::Input

    def initialize(iterable)
      super
      @save = Composite::Function.new(self, :save, 2, { self: type, origin: const_type }, :void)
    end

    def interface_declarations(stream)
      super
      stream << %$
        /**
        * @brief
        */
        #{declare(@save)};
      $
    end

  end


  #
  class Range::Bidirectional < Range::Forward

    def initialize(iterable)
      super
      @pop_back = Composite::Function.new(self, :pop_back, 1, { self: type }, :void)
      @back_view = Composite::Function.new(self, :back_view, 1, { self: const_type }, iterable.element.const_ptr_type)
      @back = Composite::Function.new(self, :back, 1, { self: const_type }, iterable.element.type)
    end

    def interface_declarations(stream)
      super
      stream << %$
        /**
        * @brief
        */
        #{declare(@pop_back)};
        /**
        * @brief
        */
        #{declare(@back_view)};
      $
      stream << %$
        /**
        * @brief
        */
        #{declare(@back)};
      $ if iterable.element.copyable?
    end

  end


  #
  class Range::RandomAccess < Range::Bidirectional

    def initialize(iterable)
      super
      @size = Composite::Function.new(self, :size, 1, { self: const_type }, :size_t)
      @view = Composite::Function.new(self, :view, 1, { self: const_type, position: :size_t }, iterable.element.const_ptr_type)
      @get = Composite::Function.new(self, :get, 1, { self: const_type, position: :size_t }, iterable.element.type)
    end

    def interface_declarations(stream)
      super
      stream << %$
        /**
        * @brief
        */
        #{declare(@size)};
        /**
        * @brief
        */
        #{declare(@view)};
      $
      stream << %$
        /**
        * @brief
        */
        #{declare(@get)};
      $ if iterable.element.copyable?
    end
  end


end