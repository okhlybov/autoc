# frozen_string_literal: true


require 'autoc/hash_set'


module AutoC


  #
  class HashMap < AssociativeContainer

    prepend Container::Hashable
    prepend Container::Sequential

    def orderable? = false

    def canonic_tag = "HashMap<#{key.type} -> #{element.type}>"

    private def _node = @_node ||= Node.new(self)
    private def _set = @_set ||= Set.new(self, _node)

    def composite_interface_declarations(stream)
      stream << %{
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
          #{_set.type} set; /**< @private */
        } #{type};
      }
      super
    end

    private def configure
      super
      dependencies << _node << _set
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
      default_create.inline_code %{
        assert(self);
        #{create_capacity}(self, 0, 1);
      }
      destroy.code %{
        #{_set.destroy}(&self->set);
      }
      size.code %{
        return #{_set.size}(&self->set);
      }
      empty.code %{
        return #{_set.empty}(&self->set);
      }
      copy.code %{
        #{_set.copy('self->set', 'source->set')};
      }
      equal.code %{
        return #{_set.equal('self->set', 'other->set')};
      }
      purge.code %{
        #{_set.purge}(&self->set);
      }
      view.inline_code %{
        #{_node.const_ptr_type} node = #{_lookup_node}(self, key);
        return node ? &node->element : NULL;
      }
      lookup_key.inline_code %{
        #{_node.const_ptr_type} node = #{_lookup_node}(self, key);
        return node ? &node->key : NULL;
      }
      put.code %{
        #{_node.type} node;
        node.key = key;
        if(!#{_set.contains}(&self->set, node)) {
          /* TODO use (future) emplace method instead of the temporary node instance */
          #{_node.custom_create}(&node, key, value);
          #{_set.put}(&self->set, node);
          #{_node.destroy(:node) if _node.destructible?};
          return 1;
        } else return 0;
      }
      set.code %{
        int replace = #{remove}(self, key);
        #{put}(self, key, value);
        return replace;
      }
      remove.code %{
        #{_node.type} node;
        node.key = key;
        return #{_set.remove}(&self->set, node);
      }
    end

  end


  # @private
  class HashMap::Range < AssociativeContainer::Range

    private def _set = @_set ||= iterable.send(:_set)

    def composite_interface_declarations(stream)
      stream << %{
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
          #{_set.range.type} set_range; /**< @private */
        } #{type};
      }
      super
    end

    private def configure
      super
      custom_create.code %{
        assert(self);
        assert(iterable);
        #{_set.range.custom_create}(&self->set_range, &iterable->set);
      }
      empty.code %{
        assert(self);
        return #{_set.range.empty}(&self->set_range);
      }
      pop_front.code %{
        assert(self);
        #{_set.range.pop_front}(&self->set_range);
      }
      view_front.code %{
        assert(self);
        assert(!#{empty}(self));
        return &#{_set.range.view_front}(&self->set_range)->element;
      }
      view_key_front.code %{
        assert(self);
        assert(!#{empty}(self));
        return &#{_set.range.view_front}(&self->set_range)->key;
      }
    end

  end

  # @private
  class HashMap::Set < HashSet

    def initialize(map, element)
      @node = element
      @omit_set_operations = true
      super(map.decorate_identifier(:_S), element, visibility: :internal)
    end

    private def configure
      super
      # Rolling out the custom set hasher to include both key and element into consideration
      # instead of using node's version which is for key searching only
      hash_code.code %{
        size_t hash;
        #{range.type} r;
        #{hasher.type} hasher;
        #{hasher.create(:hasher)};
        for(r = #{range.new}(self); !#{range.empty}(&r); #{range.pop_front}(&r)) {
          #{@node.const_ptr_type} node = #{range.view_front}(&r);
          #{hasher.update(:hasher, @node.key.hash_code('node->key'))};
          #{hasher.update(:hasher, @node.element.hash_code('node->element'))};
        }
        hash = #{hasher.result(:hasher)};
        #{hasher.destroy(:hasher)};
        return hash;
      }
    end

  end


  # @private
  class HashMap::Node < Composite

    attr_reader :key, :element

    def initialize(map)
      super(map.decorate_identifier(:_N), visibility: :internal)
      dependencies << (@key = map.key) << (@element = map.element)
    end

    def orderable? = false
    def default_constructible? = false
    def destructible? = key.destructible? || element.destructible?

    def composite_interface_declarations(stream)
      stream << %{
        /** @private */
        typedef struct {
          #{key.type} key;
          #{element.type} element;
        } #{type};
      }
      super
    end

    private def configure
      super
      def_method :void, :create, { self: type, key: key.type, element: element.type }, instance: :custom_create, require:-> { key.copyable? && element.copyable? } do
        inline_code %{
          #{key.copy('self->key', :key)};
          #{element.copy('self->element', :element)};
        }
      end
      equal.inline_code %{
        assert(self);
        assert(other);
        return #{key.equal('self->key', 'other->key')};
      }
      copy.inline_code %{
        #{create}(self, source->key, source->element);
      }
      destroy.inline_code %{
        #{key.destroy('self->key') if key.destructible?};
        #{element.destroy('self->element') if element.destructible?};
      }
      hash_code.code %{
        size_t hash;
        #{hasher.type} hasher;
        #{hasher.create(:hasher)};
        #{hasher.update(:hasher, key.hash_code('self->key'))};
        hash = #{hasher.result(:hasher)};
        #{hasher.destroy(:hasher)};
        return hash;
      }
    end

  end
end