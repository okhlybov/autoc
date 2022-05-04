# frozen_string_literal: true


require 'autoc/composite'
require 'autoc/range'


module AutoC


  # @abstract
  # Generator type for container types which contain arbitrary number of values of the same type
  # such as vector, list, map etc.
  class Container < Composite

    prepend Composite::Traversable

    attr_reader :element

    def initialize(type, element, visibility: :public)
      super(type, visibility: visibility)
      dependencies << (@element = Type.coerce(element))
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

    private def configure
      super
      def_method :int, :empty, { self: const_type } do
        header %{
          @brief Check whether container is empty

          @param[in] self container to test for emptiness
          @return non-zero if `self` contains at least one element and zero otherwise

          @since 2.0
        }
      end
      def_method :size_t, :size, { self: const_type } do
        header %{
          @brief Get number of contained elements

          @param[in] self container
          @return number of elements contained in `self`

          The function returns a size of container, i.e. a number of contained elements.

          @since 2.0
        }
      end
      def_method :int, :contains, { self: const_type, value: element.const_type }, require:-> { element.comparable? } do
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
      def_method element.const_ptr_type, :lookup, { self: const_type, value: element.const_type }, require:-> { element.comparable? } do
        header %{
          @brief Search for specific element

          @param[in] self container to search through
          @param[in] value value to look for
          @return a view of element equivalent to specified value or NULL value

          This function scans through `self` and returns a constant reference (in form of the C pointer)
          a contained element equivalent to the specified `value` or NULL value is there is no such element.

          This function usually (but not neccessarily) yields first suitable element.

          This function requires the element type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        }
      end
      def_method :void, :purge, { self: type } do
        code %{
          assert(self);
          #{destroy}(self);
          #{default_create}(self);
        }
        header %{
          @brief Remove and destroy all contained elements

          @param[in] self list to be purged

          The elements are destroyed with respective destructor.

          After call to this function the set will remain intact yet contain zero elements.

          @since 2.0
        }
      end
    end
  
    end


  # Provides generic implementation of hashable container support code.
  module Container::Hashable
    def configure
      super
      hash_code.code %{
        size_t hash;
        #{range.type} r;
        #{hasher.type} hasher;
        #{hasher.create(:hasher)};
        for(r = #{range.new}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
          #{element.const_ptr_type} p = #{range.view_front}(&r);
          #{hasher.update(:hasher, element.hash_code('*p'))};
        }
        hash = #{hasher.result(:hasher)};
        #{hasher.destroy(:hasher)};
        return hash;
      }
    end
  end


  # Provides generic implementations of sequential algorithms
  module Container::Sequential
    def configure
      super
      lookup.code %{
        #{range.type} r;
        assert(self);
        for(r = #{range.new}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
          #{element.const_ptr_type} e = #{range.view_front}(&r);
          if(#{element.equal(:value, '*e')}) return e;
        }
        return NULL;
      }
    end
  end


  class AssociativeContainer < Container

    attr_reader :key

    def initialize(type, key, element, visibility: :public)
      super(type, element, visibility: visibility)
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

    private def configure
      super
      def_method element.const_ptr_type, :view, { self: const_type, key: key.const_type } do
        header %{
          @brief Return a view of the element associated with the specified key or NULL if there is no such element
          TODO
        }
      end
      def_method :int, :put, { self: type, key: key.const_type, value: element.const_type }, require:-> { key.copyable? && element.copyable? } do
        header %{
          @brief Associate a copy of the specified element with a copy of the specified key if there is no such key present
          TODO
        }
      end
      def_method :int, :set, { self: type, key: key.const_type, value: element.const_type }, require:-> { key.copyable? && element.copyable? } do
        header %{
          @brief Associate a copy of the specified element with a copy of the specified key overriding existing key/value pair
          TODO
        }
      end
      def_method :int, :remove, { self: type, key: key.const_type } do
        header %{
          @brief Remove and destroy key and element pair referenced by the specified key if it exists
          TODO
        }
      end
      def_method element.type, :get, { self: const_type, key: key.const_type }, require:-> { element.copyable? } do
        inline_code %{
          #{element.type} result;
          #{element.const_ptr_type} e;
          assert(#{contains_key}(self, key));
          e = #{view}(self, key);
          #{element.copy(:result, '*e')};
          return result;
        }
        header %{
          @brief Return a copy of the element associated with the specified key
          TODO
        }
      end
      def_method :int, :contains_key, { self: const_type, key: key.const_type }, require:-> { key.comparable? } do
        inline_code %{
          return #{lookup_key}(self, key) != NULL;
        }
        header %{
          @brief Check for key existence

          @param[in] self container to search through
          @param[in] key key to look for
          @return non-zero if there is at least one key in `self` equal to the specified `key` and zero otherwise

          This function requires the key type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        }
      end
      def_method key.const_ptr_type, :lookup_key, { self: const_type, key: key.const_type }, require:-> { key.comparable? } do
        header %{
          @brief Search for specific key

          @param[in] self container to search through
          @param[in] key key to look for
          @return a view of key equivalent to specified key or NULL

          This function scans through `self` and returns a constant reference (in form of the C pointer)
          to the key equivalent to the specified `key` or NULL value is there is no such key.

          This function requires the key type to be *comparable* (i.e. to have a well-defined comparison operation).

          @since 2.0
        }
      end
    end

  end


  class AssociativeContainer::Range < Range::Forward
    private def configure
      super
      def_method iterable.key.const_ptr_type, :view_key_front, { self: const_type } do
        header %{
          @brief Get a view of the front key

          @param[in] self range to retrieve key from
          @return a view of a key at the range's front position

          This function is used to get a constant reference (in form of the C pointer) to the key at the range's front position.
          Refer to @ref #{take_key_front} to get an independent copy of that element.
  
          It is generally not safe to bypass the constness and to alter the value in place (although no one prevents to).
  
          @note Range must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
      def_method iterable.key.type, :take_key_front, { self: const_type }, require:-> { iterable.key.copyable? } do
        inline_code %{
          #{iterable.key.type} result;
          #{iterable.key.const_ptr_type} e;
          assert(!#{empty}(self));
          e = #{view_key_front}(self);
          #{iterable.key.copy(:result, '*e')};
          return result;
        }
        header %{
          @brief Get a copy of the front key

          @param[in] self range to retrieve key from
          @return a *copy* of key at the range's front position

          This function is used to get a *copy* of the key contained in the iterable container at the range's front position.
          Refer to @ref #{view_key_front} to get a view of the key without making an independent copy.

          This function requires the key type to be *copyable* (i.e. to have a well-defined copy operation).

          @note Range must not be empty (see @ref #{empty}).

          @since 2.0
        }
      end
    end
  end

end