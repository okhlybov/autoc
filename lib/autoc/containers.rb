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
    def destructibe? = super || element.destructible?

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
      method(:int, :contains, { target: const_rvalue, value: element.const_rvalue }, constraint:-> { element.comparable? }) do
        header %{
          @brief Look up for specific element in container

          @param[in] target container to query
          @param[in] value element to look for
          @return non-zero value if container has (at least one) element equal to the specified value and zero value otherwise.

          This function scans through the container's contents to look for an element which is considered equal to the specified value.
          The equality testing is performed with the element type's equality criterion.

          @since 2.0
        }
      end
    end

  end # Container


  # @abstract
  # Generator for C types which gain fast direct indexed access to specific elements (vectors, strings etc.)
  class ContiguousContainer < Container
    # TODO
  end # ContiguousContainer


  # @abstract
  # Generator for C types for direct access using keys of arbitrary type (hash/tree maps and alike)
  class AssociativeContainer < Container
    # TODO
  end # AssociativeContainer


end