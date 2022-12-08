# frozen_string_literal: true


require 'autoc/std'
require 'autoc/composite'


module AutoC


  using STD::Coercions
    

  # @abstract
  # Generator for C types which can contains zero or more elements of some other type
  class Container < Composite

    attr_reader :element

    def initialize(signature, element, **kws)
      super(signature, **kws)
      dependencies << (@element = element.to_type)
    end

    # For container to be copyable a copyable element type is required
    def copyable? = super && element.copyable?

    # For container to be comparable a comparable element type is required
    def comparable? = super && element.comparable?

    # For container to be orderable an orderable element type is required
    def orderable? = super && element.orderable?

    # A destructible element type mandates creation of the container's destructor
    def destructible? = super || element.destructible?

    # For container to be hashable a hashable element type is required
    def hashable? = super && element.hashable?
  
    def tag = "#{signature}<#{element}>"

  private

    def configure
      super
      method(:int, :empty, { target: const_rvalue }).configure do
        header %{
          @brief Check container for emptiness

          @param[in] target container to check
          @return non-zero value if container is empty (i.e. contains no elements) and zero value otherwise

          @note This function's behavior must be consistent with @ref #{type.size}.

          @since 2.0
        }
      end
      method(:size_t, :size, { target: const_rvalue }).configure do
        header %{
          @brief Return number of contained elements

          @param[in] target container to query
          @return number of contained elements

          @note This function's behavior must be consistent with @ref #{type.empty}.

          @since 2.0
        }
      end
      method(:int, :contains, { target: const_rvalue, value: element.const_rvalue }, constraint:-> { element.comparable? }).configure do
        header %{
          @brief Look up for specific element in container

          @param[in] target container to query
          @param[in] value element to look for
          @return non-zero value if container has (at least one) element equal to the specified value and zero value otherwise

          This function scans through the container's contents to look for an element which is considered equal to the specified value.
          The equality testing is performed with the element type's equality criterion.

          @since 2.0
        }
      end
    end

  end # Container


  # @abstract
  # Generator for C types for direct access using keys of specific type (hash/tree maps, string, vector etc.)
  class IndexedContainer < Container

    attr_reader :index

    def initialize(type, element, index, **kws)
      super(type, element, **kws)
      dependencies << (@index = index.to_type)
    end

    # For associative container to be copyable both hashable element and index types are required
    def copyable? = super && index.copyable?

    # For associative container to be comparable both hashable element and index types are required
    def comparable? = super && index.comparable?

    # For associative container to be orderable both hashable element and index types are required
    def orderable? = super && index.orderable?

    # The associative destructible element and index types mandates creation of the container's destructor
    def destructible? = super || index.destructible?

    # For associative container to be hashable both hashable element and index types are required
    def hashable? = super && index.hashable?
  
  private

    def configure
      super
      method(:int, :check, { target: const_rvalue, index: index.const_rvalue } ).configure do
        header %{
          @brief Validate specified index

          @param[in] target container to query
          @param[in] index index to verify
          @return non-zero value if there is an element associated with specified index and zero value otherwise

          This function performs the index validity check.
          For the contiguous containers (vector, string etc.) the yields non-zero value if the index passes the boundaries check.
          For the mappings (hash/tree maps) this yields non-zero value if there exists a index->element association.

          In any case, this function should be used for the index validation prior getting direct access to contained elements
          as the container functions do not normally do it themselves for performance reasons.

          @since 2.0
        }
      end
      method(element.const_lvalue, :view, { target: const_rvalue, index: index.const_rvalue } ).configure do
        header %{
          @brief Get a view of the element

          @param[in] target container
          @param[in] index lookup index
          @return a view of contained element

          This function returns a constant view of the contained element associated with specified index in the form constant C pointer to the storage.
          It is generally not wise to modify the value pointed to (especially in the case of mapping).

          It is the caller's responsibility to check for the index validity prior calling this function (see @ref #{type.check}).

          @since 2.0
        }
      end
      method(element, :get, { target: const_rvalue, index: index.const_rvalue }, constraint:-> { element.copyable? } ).configure do
        header %{
          @brief Get specific element

          @param[in] target container
          @param[in] index lookup index
          @return a copy of contained element

          This function returns an independent copy of the contained element associated with specified index.

          It is the caller's responsibility to check for the index validity prior calling this function (see @ref #{type.check}).

          @since 2.0
        }
        code %{
          #{result} r;
          #{element.const_lvalue} e;
          assert(target);
          assert(#{check.(target, index)});
          e = #{view.(target, index)};
          #{element.copy.(:r, '*e')};
          return r;
        }
      end
      method(:void, :set, { target: rvalue, index: index.const_rvalue, value: element.const_rvalue }, constraint:-> { element.copyable? } ).configure do
        header %{
          @brief Set specific element

          @param[in] target container
          @param[in] index lookup index
          @param[in] value source value

          This function unconditionally sets the element at specified index to a copy of the source value.
          A previous element (if any) is destroyed with specific destructor.

          It is the caller's responsibility to check for the index validity prior calling this function (see @ref #{type.check}).

          @since 2.0
        }
      end

    end

  end # IndexedContainer


  # @abstract
  # Generator for C types which gain fast direct indexed access to specific elements (vectors, strings etc.)
  class ContiguousContainer < IndexedContainer
    
  private
    
    def configure
      super
      # It's OK to modify contents of the vector-backed containers in-place
      # This does not work for real associative containers (maps/dicts), though
      set.configure do
        code %{
          #{element.lvalue} e;
          assert(target);
          assert(#{check.(target, index)});
          e = (#{element.lvalue})#{view.(target, index)};
          #{element.destroy.('*e') if element.destructible?};
          #{element.copy.('*e', value)};
        }
      end
    end

  end # ContiguousContainer


  # @abstract
  # Generator for C types which implement associative containers such as hash/tree maps
  class AssociativeContainer < IndexedContainer

  private

    def configure
      super
      #method(:int, :put, { target: rvalue, value: element.const_rvalue }, constraint:-> { element.copyable? } )
    end

  end # AssociativeContainer


end