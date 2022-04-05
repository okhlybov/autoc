# frozen_string_literal: true


require 'autoc/container'
require 'autoc/hash_set'


module AutoC


  #
  class HashMap < AssociativeContainer

    prepend Container::Hashable
    prepend Container::Sequential

    private attr_reader :_node, :_set

    def initialize(type, key, element, visibility = :public)
      super
      @_node = Node.new(self, self.key, self.element)
      @_set = Set.new(self, _node, self.key, self.element)
      @range = Range.new(self, visibility, _set)
      dependencies << range << _node << _set
    end

    def orderable? = false

    def canonic_tag = "HashMap<#{key.type} -> #{element.type}>"

    def composite_interface_declarations(stream)
      stream << %$
        /**
          #{defgroup}

          @brief Hash-based unordered collection of elements of type #{element.type} mapped to unique keys of type #{key.type}

          For iteration over the map elements refer to @ref #{range.type}.

          @see C++ [std::unordered_map<K,T>](https://en.cppreference.com/w/cpp/container/unordered_map)

          @since 2.0
        */
        /**
          #{ingroup}
          @brief Opaque structure holding state of the hash map
          @since 2.0
        */
        typedef struct {
          #{_set.type} set;
        } #{type};
      $
      super
    end

    private def configure
      super
      def_method :void, :create_capacity, { self: type, capacity: :size_t, manage_capacity: :int } do
        code %{
          assert(self);
          #{_set.create_capacity}(&self->set, capacity, manage_capacity);
        }
        header %{
          @brief Create a map with specified initial capacity
          TODO
        }
      end
      def_method _node.const_ptr_type, :_lookup_node, { self: const_type, key: key.const_type }, visibility: :private do
        code %{
          #{_node.type} node;
          node.key = key; /* .element remains uninitialized as it's not considered by the comparison code */
          return #{_set.lookup}(&self->set, node);
        }
      end
      inline_code :default_create, %{
        assert(self);
        #{create_capacity}(self, 0, 1);
      }
      code :destroy, %{
        #{_set.destroy}(&self->set);
      }
      code :size, %{
        return #{_set.size}(&self->set);
      }
      code :empty, %{
        return #{_set.empty}(&self->set);
      }
      code :copy, %{
        #{_set.copy}(&self->set, &source->set);
      }
      code :equal, %{
        return #{_set.equal}(&self->set, &other->set);
      }
      code :purge, %{
        #{_set.purge}(&self->set);
      }
      inline_code :view, %{
        #{_node.const_ptr_type} node = #{_lookup_node}(self, key);
        return node ? &node->element : NULL;
      }
      inline_code :lookup_key, %{
        #{_node.const_ptr_type} node = #{_lookup_node}(self, key);
        return node ? &node->key : NULL;
      }
      code :put, %{
        #{_node.type} node;
        node.key = key;
        if(!#{_set.contains}(&self->set, node)) {
          #{key.copy('node.key', :key)};
          #{element.copy('node.element', :value)};
          #{_set.put}(&self->set, node);
          return 1;
        } else return 0;
      }
      code :set, %{
        int replace = #{remove}(self, key);
        #{put}(self, key, value);
        return replace;
      }
      code :remove, %{
        #{_node.type} node;
        node.key = key;
        return #{_set.remove}(&self->set, node);
      }
    end

  end


  # @private
  class HashMap::Range < AssociativeContainer::Range

    attr_reader :_set_range

    def initialize(iterable, visibility, _set)
      super(iterable, visibility)
      @_set_range = _set.range
    end

    def composite_interface_declarations(stream)
      stream << %$
        /**
          #{defgroup}
          @ingroup #{iterable.type}

          @brief #{canonic_desc}

          This range implements the @ref #{archetype} archetype.

          @see @ref Range

          @since 2.0
        */
        /**
          #{ingroup}
          @brief Opaque structure holding state of the map's range
          @since 2.0
        */
        typedef struct {
          #{_set_range.type} set_range; /**< @private */
        } #{type};
      $
      super
    end

    private def configure
      super
      code :custom_create, %{
        assert(self);
        assert(iterable);
        #{_set_range.custom_create}(&self->set_range, &iterable->set);
      }
      code :empty, %{
        assert(self);
        return #{_set_range.empty}(&self->set_range);
      }
      code :pop_front, %{
        assert(self);
        #{_set_range.pop_front}(&self->set_range);
      }
      code :view_front, %{
        assert(self);
        assert(!#{empty}(self));
        return &#{_set_range.view_front}(&self->set_range)->element;
      }
      code :view_key_front, %{
        assert(self);
        assert(!#{empty}(self));
        return &#{_set_range.view_front}(&self->set_range)->key;
      }
    end

  end

  # @private
  class HashMap::Set < HashSet

    private attr_reader :_node, :_node_key, :_node_element

    def initialize(map, element, _node_key, _node_element)
      @_node = element
      @_node_key = _node_key
      @_node_element = _node_element
      @omit_set_operations = true
      super(Once.new { map.decorate_identifier(:_set) }, element, :internal)
    end

    private def configure
      super
      # Rolling out the custom set hasher to include both key and element into consideration
      # instead of using node's version which is for key searching only
      code :hash_code, %{
        size_t hash;
        #{range.type} r;
        #{hasher.type} hasher;
        #{hasher.create(:hasher)};
        for(r = #{get_range}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
          #{_node.const_ptr_type} node = #{range.view_front}(&r);
          #{hasher.update(:hasher, _node_key.hash_code('node->key'))};
          #{hasher.update(:hasher, _node_element.hash_code('node->element'))};
        }
        hash = #{hasher.result(:hasher)};
        #{hasher.destroy(:hasher)};
        return hash;
      }
    end

  end


  # @private
  class HashMap::Node < Composite

    private attr_reader :_key, :_element

    def initialize(map, key, element)
      super(Once.new { map.decorate_identifier(:_node) }, :internal)
      dependencies << (@_key = key) << (@_element = element)
    end

    def default_constructible? = false
    def orderable? = false
    def destructible? = _key.destructible? || _element.destructible?

    def copy(value, source) = "#{value} = #{source}"

    def composite_interface_declarations(stream)
      stream << %$
        typedef struct {
          #{_key.type} key;
          #{_element.type} element;
        } #{type};
      $
      super
    end

    private def configure
      super
      def_method :void, :create, { self: type, key: _key.type, element: _element.type }, instance: :custom_create do
        inline_code %{
          #{_key.copy('self->key', :key)};
          #{_element.copy('self->element', :element)};
        }
      end
      inline_code :equal, %{
        assert(self);
        assert(other);
        return #{_key.equal('self->key', 'other->key')};
      }
      inline_code :copy, %{
        #{destroy}(self);
        #{create}(self, source->key, source->element);
      }
      inline_code :destroy, %{
        #{_key.destroy('self->key') if _key.destructible?};
        #{_element.destroy('self->element') if _element.destructible?};
      }
      code :hash_code, %{
        size_t hash;
        #{hasher.type} hasher;
        #{hasher.create(:hasher)};
        #{hasher.update(:hasher, _key.hash_code('self->key'))};
        hash = #{hasher.result(:hasher)};
        #{hasher.destroy(:hasher)};
        return hash;
      }
    end

  end
end