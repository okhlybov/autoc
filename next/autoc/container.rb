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
      # Declare the common container functions
      @size = function(self, :size, 1, { self: const_type }, :size_t)
      @empty = function(self, :empty, 1, { self: const_type }, :int)
      @contains = function(self, :contains, 1, { self: const_type, value: self.element.const_type }, :int)
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

    private def relative_position(other) = other.equal?(range) ? 0 : super # Extra check to break the iterable <-> range cyclic dependency

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
          * @brief Create a new empty container
          */
      #{declare(default_create)};
      $ if default_constructible?
      stream << %$
        /**
          * @brief Destroy the container along with all contained elements
          *
          * The elements are destroyed with the element's respective destructor.
          */
        #{declare(destroy)};
      $ if destructible?
      stream << %$
        /**
          * @brief Create a container with the copies of the source container's elements
          */
        #{declare(copy)};
      $ if copyable?
      stream << %$
        /**
          * @brief Move the container to a new location with all its elements
          */
        #{declare(move)};
      $ if movable?
      stream << %$
        /**
          * @brief Return non-zero if both containers are considered equal by contents
          */
        #{declare(equal)};
      $ if comparable?
      stream << %$
        /**
         * @brief Return non-zero if there is at least one element in the container equal to the specified value
         */
        #{declare(@contains)};
      $ if element.comparable?
      stream << %$
        /**
          * @brief Return less-equal-more value for two containers
          */
        #{declare(compare)};
      $ if orderable?
      stream << %$
        /**
          * @brief Return number of contained elements in the container
          */
        #{declare(@size)};
        /**
          * @brief Return non-zero if there are no elements in the container and zero otherwise
          */
        #{declare(@empty)};
      $
    end

  end


  # Provides the generic implementation of hashable container support code.
  module Container::Hashable

    def composite_interface_definitions(stream)
      super
      stream << %$
        /**
          * @brief Return hash code for the container based on hash codes of contained elements
          */
        #{declare(code)};
      $ if hashable?
    end

    def definitions(stream)
      super
      stream << %$
        #{define(code)} {
          size_t hash;
          #{hasher.type} hasher;
          #{hasher.create(:hasher)};
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_ptr_type} p = #{range.front_view}(&r);
            size_t h = #{element.code('*p')};
            #{hasher.update(:hasher, :h)};
          }
          hash = #{hasher.result(:hasher)};
          #{hasher.destroy(:hasher)};
          return hash;
        }
      $ if hashable?
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