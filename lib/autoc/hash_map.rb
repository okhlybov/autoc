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

    def _node = @_node ||= _node_class.new(identifier(:_node, abbreviate: true), { index: index, element: element }, visibility: :internal)

    def _set = @_set ||= _set_class.new(identifier(:_set, set_operations: false, abbreviate: true), _node, visibility: :internal)

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
            @brief Hash-based unordered collection of {#{index}->#{element}} pairs

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

    def _bucket_range = @_bucket_range ||= _set._bucket.range

  private

    def configure
      super
      method(_set._bucket.lvalue, :_find_set_bucket, { target: const_rvalue, value: index.const_rvalue }, inline: true, visibility: :internal).configure do
        code %{
          /* this code must stay coherent with #{_set._find_bucket}() but use custom hasher which considers index only */
          return (#{_set._bucket.lvalue})#{_set._buckets.view.('target->set.buckets', index.hash_code.(value)+'&target->set.hash_mask')};
        }
      end
      method(_node.lvalue, :_find_node, { target: const_rvalue, value: index.const_rvalue }, visibility: :internal).configure do
        code %{
          #{_bucket_range} r;
          #{_set._bucket.const_lvalue} b = #{_find_set_bucket.(target, value)};
          for(r = #{_bucket_range.new.('*b')}; !#{_bucket_range.empty.(:r)}; #{_bucket_range.pop_front.(:r)}) {
            #{_node.const_lvalue} node = #{_bucket_range.view_front.(:r)};
            /* use custom equality testing to bypass the #{_node.equal}()'s element treatment */
            if(#{index.equal.('node->index', value)}) return (#{_node.lvalue})node;
          }
          return NULL;
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
          if(node = #{_find_node.(target, index)}) {
            #{_node.destroy.('*node') if _node.destructible?};
            #{_node.custom_create.('*node', index, value)}; /* override node's contents in-place */
          } else {
            #{_node} node;
            #{_set._bucket.lvalue} b = #{_find_set_bucket.(target, index)};
            /* construct temporary node as POD value; actual copying will be performed by the list itself */
            node.index = index;
            node.element = value;
            #{_set._bucket.push_front.('*b', :node)};
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
          return #{_find_node.(target, index)} != NULL;
        }
      end
      view.configure do
        code %{
          assert(target);
          #{_node.lvalue} node = #{_find_node.(target, index)};
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
    def _bucket_class = HashMap::HashSetList
  end # HashSet


  class HashMap::HashSetList < List
  
  private

    def configure
      super
    end

  end # List


  class HashMap::Range < AssociativeRange

    def render_interface(stream)
      if public?
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

    # :nodoc:
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