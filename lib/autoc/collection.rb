# frozen_string_literal: true


require 'autoc/std'
require 'autoc/composite'


module AutoC


  using STD::Coercions
    

  # @abstract
  # Generator for C types which contain zero or more elements of a particular type
  class Collection < Composite

    attr_reader :element

    attr_reader :range

    def self.new(*args, **kws)
      obj = super
      obj.references << obj.range # Range has to be referenced after the iterable object gets fully configured
      obj
    end

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
  
    def type_tag = @type_tag ||= "#{signature}<#{element}>"

  private

    def configure
      super
      method(:int, :empty, { target: const_rvalue })
      method(:size_t, :size, { target: const_rvalue })
      # Separate certain methods creation from documenting due to mutual dependency
      empty.configure do
        header %{
          @brief Check container for emptiness

          @param[in] target container to check
          @return non-zero value if container is empty (i.e. contains no elements) and zero value otherwise

          @note This function's behavior must be consistent with @ref #{size}.

          @since 2.0
        }
      end
      size.configure do
        header %{
          @brief Return number of contained elements

          @param[in] target container to query
          @return number of contained elements

          @note This function's behavior must be consistent with @ref #{empty}.

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
      method(element.const_lvalue, :find_first, { target: const_rvalue, value: element.const_rvalue }, constraint:-> { element.comparable? }).configure do
        header %{
          @brief Search for specific element

          @param[in] target container to search through
          @param[in] value value to look for
          @return a view of element equivalent to specified value or NULL value

          This function scans through `target` and returns a constant reference (in form of the C pointer)
          a contained element equivalent to the specified `target` or NULL value is there is no such element.

          This function usually (but not neccessarily) yields first suitable element.

          This function requires the element type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        }
      end
    end

  end # Collection


end