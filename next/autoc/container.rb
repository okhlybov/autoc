# frozen_string_literal: true


require 'autoc/composite'


module AutoC


  # @abstract
  # Generator type for container types which contain arbitrary number of values of the same type
  # such as vector, list, map etc.
  class Container < Composite

    attr_reader :element

    attr_reader :range

    def initialize(type, element, visibility)
      super(type, visibility)
      @element = Type.coerce(element)
      dependencies << self.element
    end

    private def configure
      super
      def_method :size_t, :size, { self: const_type } do
        header %{
          @brief Get number of contained elements

          @param[in] self container
          @return number of elements contained in `self`

          The function returns a size of container, i.e. a number of contained elements.

          @since 2.0
        }
      end
      def_method :int, :empty, { self: const_type } do
        header %{
          @brief Check whether container is empty

          @param[in] self container to test for emptiness
          @return non-zero if `self` contains at least one element and zero otherwise

          @since 2.0
        }
      end
      def_method element.const_ptr_type, :lookup, { self: const_type, value: self.element.const_type }, require:-> { element.comparable? } do
        header %{
          @brief Search for specific element

          @param[in] self container to search through
          @param[in] value value to look for
          @return a view of element equivalent to specified value or NULL value

          This function scans through `self` and returns a constant reference (in form of the C pointer)
          to the first contained element equivalent to the specified `value` or NULL value is there is no such element.

          This function requires the element type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        }
      end
      def_method :int, :contains, { self: const_type, value: self.element.const_type }, require:-> { element.comparable? } do
        inline_code %{
          return #{lookup}(self, value) != NULL;
        }
        header %{
          @brief Check for element existence

          @param[in] self container to search through
          @param[in] value element to look for
          @return non-zero if there is at least one element in `self` equal to the specified `value` and zero otherwise

          This functions scans through the container and returns non-zero value if `self` contains at least one element
          equivalent to the specified `value` and zero value otherwise.

          This function requires the element type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        }
      end
    end

    # Additional container-specific trait restrictions

    # For container to be copyable a copyable element type is required
    def copyable? = super && element.copyable?

    # For container to be comparable a comparable element type is required
    def comparable? = super && element.comparable?

    # For container to be orderable an orderable element type is required
    def orderable? = super && element.orderable?

    # A destructible element type mandates creation of the container's destructor
    def destructibe? = super || element.destructible?

    # For container to be hashable a hashable element type is required
    def hashable? = super && element.hashable?

    private def relative_position(other) = other.equal?(range) ? 0 : super # Extra check to break the iterable <-> iterable.range cyclic dependency

  end


  # Provides the generic implementation of hashable container support code.
  module Container::Hashable
    def configure
      super
      code :hash_code, %{
        size_t hash;
        #{range.type} r;
        #{hasher.type} hasher;
        #{hasher.create(:hasher)};
        for(r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
          #{element.const_ptr_type} p = #{range.view_front}(&r);
          #{hasher.update(:hasher, element.hash_code('*p'))};
        }
        hash = #{hasher.result(:hasher)};
        #{hasher.destroy(:hasher)};
        return hash;
      }
    end
  end


  module Container::Sequential
    def configure
      super
      code :lookup, %{
        #{range.type} r;
        assert(self);
        for(r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
          #{element.const_ptr_type} e = #{range.view_front}(&r);
          if(#{element.equal(:value, '*e')}) return e;
        }
        return NULL;
      }
    end
  end


  class AssociativeContainer < Container

    attr_reader :key

    attr_reader :key_range

    def initialize(type, key, element, visibility)
      super(type, element, visibility)
      @key = Type.coerce(key)
      dependencies << self.key
    end

    # Additional container-specific trait restrictions

    # For container to be copyable both hashable element and key types are required
    def copyable? = super && key.copyable?

    # For container to be comparable both hashable element and key types are required
    def comparable? = super && key.comparable?

    # For container to be orderable both hashable element and key types are required
    def orderable? = super && key.orderable?

    # The destructible element and key types mandates creation of the container's destructor
    def destructibe? = super || key.destructible?

    # For container to be hashable both hashable element and key types are required
    def hashable? = super && key.hashable?
  end


end