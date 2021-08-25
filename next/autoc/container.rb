require 'autoc/composite'


module AutoC


  # @abstract
  # Generator type for container types which contain arbitrary number of values of the same type
  # such as vector, list, map etc.
  class Container < Composite

    attr_reader :element

    def initialize(type, element)
      super(type)
      @element = Type.coerce(element)
      @initial_dependencies << self.element
      @generate_declarations = true # Emit generic documented method declarations
    end

    # Additional container-specific trait restrictions

    # For container to be comparable a comparable element type is required
    def comparable? = super && element.comparable?

    # For container to be orderable an orderable element type is required
    def orderable? = super && element.orderable?

    # A destructible element type mandates creation of the container's destructor
    def destructibe? = super || element.destructible?

    # For container to be hashable a hashable element type is required
    def hashable? = super && element.hashable?

    def interface_definitions(stream)
      super
      if @generate_declarations
        stream << %$
          /**
           * @addtogroup #{type}
           * @{
           */
        $
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
           * @brief Return hash code for the container based on hash codes of contained elements
           */
          #{declare(code)};
        $ if hashable?
        stream << %$
          /**
           * @brief Return less-equal-more value for two containers
           */
          #{declare(compare)};
        $ if orderable?
        stream << %$/** @} */$
      end
    end
  
  end


  # Provides generic implementation of the code() function based on container-specific ranges
  module Container::Hashable

    @@hashable_counter = 0 # Counter used to generate a hashable-unique type hash code

    def definitions(stream)
      super
      stream << %$
        #{define(code)} {
          size_t hash;
          #{range.type} r;
          #{hasher.type} hasher;
          #{hasher.create(:hasher)};
          #{hasher.update(:hasher, @@hashable_counter += 1)};
          for(#{range.create}(&r, self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
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


end