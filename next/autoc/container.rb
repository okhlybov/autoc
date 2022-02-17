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
      # Declare common container functions
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
          @brief Create a new empty container

          @param[out] self container to be initialized

          The container constructed with this function contains no elements.

          @note Previous contents of `*self` is overwritten.

          @since 2.0
        */
        #{declare(default_create)};
      $ if default_constructible?
      stream << %$
        /**
          @brief Destroy the container along with all contained elements

          @param[in] self container to be destructed

          Upon destruction all contained elements get destroyed in turn with respective destructors and allocated memory is reclaimed.

          @since 2.0
        */
        #{declare(destroy)};
      $ if destructible?
      stream << %$
        /**
          @brief Create a new container with copies of the source container's elements

          @param[out] self container to be initialized
          @param[in] source container to obtain the elements from

          The container constructed with this function contains *copies* of all elements from `source`.

          This function requires the element type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Previous contents of `*self` is overwritten.

          @since 2.0
        */
        #{declare(copy)};
      $ if copyable?
      stream << %$
        /**
          @private
          @brief Move the container to a new location with all its elements
        */
        #{declare(move)};
      $ if movable? # TODO
      stream << %$
        /**
          @brief Check whether two containers are equal by contents

          @param[in] self container to compare
          @param[in] other container to compare
          @return non-zero if the containers are equal by contents and zero otherwise

          The containers are considered equal if they contain the same number of the elements which in turn are pairwise equal.
          The exact semantics is container-specific, e.g. sequence containers like vector of list mandate the equal elements
          the elements are compared sequentially whereas unordered containers such as sets have no notion of the specific element position.

          This function requires the element type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        */
        #{declare(equal)};
      $ if comparable?
      stream << %$
        /**
          @brief Check whether container contains the specified element

          @param[in] self container to search through
          @param[in] value element to look for
          @return non-zero if there is at least one element in `self` equal to the specified `value` and zero otherwise

          This function requires the element type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        */
        #{declare(@contains)};
      $ if element.comparable?
      stream << %$
        /**
          @brief Compute the ordering of two containers

          @param[in] self container to order
          @param[in] other container to order
          @return zero if containers are considered equal, negative value if `self` < `other` and positive value if `self` > `other`

          The function computes the ordering of two containers based on respective contents.

          This function requires the element type to be *orderable* (i.e. to have a well-defined less-equal-more relation operation).

          @since 2.0
        */
        #{declare(compare)};
      $ if orderable?
      stream << %$
        /**
          @brief Get number of contained elements

          @param[in] self container
          @return number of elements contained in `self`

          The function returns a size of container, i.e. a number of contained elements.

          @since 2.0
        */
        #{declare(@size)};
        /**
          @brief Check whether container is empty

          @param[in] self container to test for emptiness
          @return non-zero if `self` contains at least one element and zero otherwise

          @since 2.0
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
          @brief Return hash code for container

          @param[in] self container to get hash code for
          @return hash code

          The function computes a hash code - an integer value that somehow identifies the container's contents.

          This is done by employing the element's hash function, hence this function requires the container's
          element type to be *hashable* (i.e. to have a well-defined hash function).

          @since 2.0
        */
        #{declare(hash_code)};
        $ if hashable?
    end

    def definitions(stream)
      super
      stream << %$
        #{define(hash_code)} {
          size_t hash;
          #{hasher.type} hasher;
          #{hasher.create(:hasher)};
          for(#{range.type} r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
            #{element.const_ptr_type} p = #{range.front_view}(&r);
            #{hasher.update(:hasher, element.hash_code('*p'))};
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