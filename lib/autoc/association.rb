# frozen_string_literal: true


require 'autoc/std'
require 'autoc/collection'


module AutoC


  using STD::Coercions
    

  # @abstract
  # Generator for C types for direct access using index of specific type (hash/tree maps, string, vector etc.)
  class Association < Collection

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

    def type_tag = @type_tag ||= "#{signature}<#{element},#{index}>"
  
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

          It is the caller's responsibility to check for the index validity prior calling this function (see @ref #{check}).

          @since 2.0
        }
      end
      method(element, :get, { target: const_rvalue, index: index.const_rvalue }, inline: true, constraint:-> { element.copyable? } ).configure do
        dependencies << check << view
        header %{
          @brief Get specific element

          @param[in] target container
          @param[in] index lookup index
          @return a copy of contained element

          This function returns an independent copy of the contained element associated with specified index.

          It is the caller's responsibility to check for the index validity prior calling this function (see @ref #{check}).

          @since 2.0
        }
        inline_code %{
          #{result} r;
          #{element.const_lvalue} e;
          assert(target);
          assert(#{check.(target, index)});
          e = #{view.(target, index)};
          #{element.copy.(:r, '*e')};
          return r;
        }
      end
      method(:void, :set, { target: rvalue, index: index.const_rvalue, value: element.const_rvalue }, constraint:-> { index.copyable? && element.copyable? } ).configure do
        header %{
          @brief Set specific element

          @param[in] target container
          @param[in] index lookup index
          @param[in] value source value

          This function unconditionally sets the element at specified index to a copy of the source value.
          A previous element (if any) is destroyed with specific destructor.

          It is the caller's responsibility to check for the index validity prior calling this function (see @ref #{check}).

          @since 2.0
        }
      end
    end

  end # Association


end