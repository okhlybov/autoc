# frozen_string_literal: true


require 'autoc/record'
require 'autoc/hash_set'
require 'autoc/association'


module AutoC


  using STD::Coercions


  class HashMap < Association

    def _range_class = Range

    def _node_class = Record

    def _set_class = HashMap::HashSet

    def range = @range ||= _range_class.new(self, visibility: visibility)

    def _node = @_node ||= _node_class.new(identifier(:_node, abbreviate: true), { index: index, element: element }, _master: self, visibility: :internal)

    def _set = @_set ||= _set_class.new(identifier(:_set, set_operations: false, abbreviate: true), _node, _master: self, visibility: :internal)

    def orderable? = _set.orderable?

    def initialize(*args, **kws)
      super
      dependencies << _set
    end

    def render_interface(stream)
      if public?
        stream << %{
          /**
            #{defgroup}
            
            @brief Unordered collection of elements of type #{element} associated with unique index of type #{index}.

            For iteration over the set elements refer to @ref #{range}.

            @see C++ [std::unordered_map<K,T>](https://en.cppreference.com/w/cpp/container/unordered_map)

            @since 2.0
          */
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash map
            @since 2.0
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{_set} set; /**< @private */
        } #{signature};
      }
    end

  private

    def configure
      super
      method(:int, :remove, { target: rvalue, index: index.const_rvalue }, constraint:-> { index.comparable? }).configure do
        code %{
          assert(target);
          return #{_set._remove_index_node.('target->set', index)};
        }
        header %{
          @brief Remove element associated with index

          @param[in] target map to process
          @param[in] index index to look for
          @return non-zero value on successful removal and zero value otherwise

          This function removes and destroys index and associated element if any.
          The function returns zero value if `target` contains no such association.

          @since 2.0
        }
      end
      default_create.configure do
        code %{
          assert(target);
          #{_set.default_create.('target->set')};
        }
      end
      set.configure do
        code %{
          #{_node.lvalue} node;
          assert(target);
          assert(target);
          node = #{_set._find_index_node.('target->set', index)};
          if(node) {
            #{_node.destroy.('*node') if _node.destructible?};
            #{_node.custom_create.('*node', index, value)}; /* override node's contents in-place */
          } else {
            #{_node} node;
            #{_set._slot.lvalue} s = (#{_set._slot.lvalue})#{_set._find_index_slot.('target->set', index)};
            /* construct temporary node as POD value; actual copying will be performed by the list itself */
            node.index = index;
            node.element = value;
            #{_set._slot.push_front.('*s', :node)};
            ++target->set.size; /* bypassing set's element manipulation functions incurs manual size management */
          }
        }
      end
      destroy.configure do
        code %{
          assert(target);
          #{_set.destroy.('target->set')};
        }
      end
      copy.configure do
        code %{
          assert(target);
          assert(source);
          #{_set.copy.('target->set', 'source->set')};
        }
      end
      equal.configure do
        code %{
          assert(left);
          assert(right);
          return #{_set.equal.('left->set', 'right->set')};
        }
      end
      hash_code.configure do
        code %{
          assert(target);
          return #{_set.hash_code.('target->set')};
        }
      end
      empty.configure do
        code %{
          assert(target);
          return #{_set.empty.('target->set')};
        }
      end
      size.configure do
        code %{
          assert(target);
          return #{_set.size.('target->set')};
        }
      end
      contains.configure do
        code %{
          assert(target);
          return #{find_first.(target, value)} != NULL;
        }
      end
      check.configure do
        code %{
          assert(target);
          return #{_set._find_index_node.('target->set', index)} != NULL;
        }
      end
      view.configure do
        code %{
          #{_node.lvalue} node;
          assert(target);
          node = #{_set._find_index_node.('target->set', index)};
          return node ? &node->element : NULL;
        }
      end
      find_first.configure do
        code %{
          #{range} r;
          assert(target);
          for(r = #{range.new.(target)}; !#{range.empty.(:r)}; #{range.pop_front.(:r)}) {
            #{element.const_lvalue} e = #{range.view_front.(:r)};
            if(#{element.equal.('*e', value)}) return e;
          }
          return NULL;
        }
      end
    end

  end # HashMap


  class HashMap::HashSet < HashSet

    def _slot_class = HashMap::List

    attr_reader :_index

    def initialize(*args, **kws)
      super
      _map = _master # this set is a subcomponent of the map
      @_index = _map.index
    end

  private

    def configure
      super
      method(_slot.const_lvalue, :_find_index_slot, { target: const_rvalue, index: _index.const_rvalue }, visibility: :internal).configure do
        # Find slot based on the index hash code only bypassing element
        dependencies << _find_slot
        inline_code _find_slot_hash(_index.hash_code.(index))
      end
      method(element.lvalue, :_find_index_node, { target: const_rvalue, index: _index.const_rvalue }, visibility: :internal).configure do
        code %{
          #{_slot._node_p} curr;
          #{_slot._node_p} prev;
          #{_slot.const_lvalue} s = #{_find_index_slot.(target, index)};
          return #{_slot._find_index_node.('*s', index, :prev, :curr)} ? &curr->element : NULL;
        }
      end
      method(:int, :_remove_index_node, { target: rvalue, index: _index.const_rvalue }, visibility: :internal).configure do
        code %{
          int c;
          #{_slot.lvalue} s = (#{_slot.lvalue})#{_find_index_slot.(target, index)};
          c = #{_slot._remove_index_node.('*s', index)};
          if(c) --target->size;
          return c;
        }
      end
    end

  end # HashSet


  class HashMap::List < List

    attr_reader :_index
  
    def initialize(*args, **kws)
      super
      _map = _master._master # this list is a subcomponent of a set which is in turn a subcomponent of the map
      @_index = _map.index
    end

  private

    def configure
      super
      method(:int, :_find_index_node, { target: const_rvalue, index: _index.const_rvalue, prev_p: _node_pp, curr_p: _node_pp }, constraint:-> { _index.comparable? }).configure do
        # Locate node satisfying default element equality condition, return this and previous nodes
        code _locate_node_equal(_index.equal.('curr->element.index', index))
      end
      method(:int, :_remove_index_node, { target: rvalue, index: _index.const_rvalue }, constraint:-> { _index.comparable? }).configure do
        code _remove_first(_find_index_node.(target, index, :prev, :curr))
      end
    end

  end # List


  class HashMap::Range < AssociativeRange

    def render_interface(stream)
      if public?
        render_type_description(stream)
        stream << %{
          /**
            #{ingroup}
            @brief Opaque structure holding state of the hash map's range
            @since 2.0
          */
        }
      else
        stream << PRIVATE
      end
      stream << %{
        typedef struct {
          #{_range} set; /**< @private */
        } #{signature};
      }
    end

    # @private
    def _range = @range ||= _iterable._set.range

  private
  
    def configure
      super
      method(iterable._node.const_lvalue, :_view_node, { range: const_rvalue }, inline: true, visibility: :internal).configure do
        code %{
          assert(!#{empty.(range)});
          return #{_range.view_front.('range->set')};
        }
      end
      custom_create.configure do
        code %{
          assert(range);
          assert(iterable);
          #{_range.default_create.('range->set', '&iterable->set')};
        }
      end
      empty.configure do
        code %{
          assert(range);
          return #{_range.empty.('range->set')};
        }
      end
      pop_front.configure do
        code %{
          assert(range);
          #{_range.pop_front.('range->set')};
        }
      end
      view_front.configure do
        code %{
          assert(range);
          return &#{_view_node.(range)}->element;
        }
      end
      view_index_front.configure do
        code %{
          assert(range);
          return &#{_view_node.(range)}->index;
        }
      end
    end

  end # Range


end